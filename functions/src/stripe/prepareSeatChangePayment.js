// functions/src/stripe/prepareSeatChangePayment.js

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');

const { db } = require('../config/firebase');
const { assertAuth, assertCompanyAccount } = require('../helpers/assertions');
const { updateCompanyMirror } = require('../helpers/companyMirror');
const { getStripe } = require('../config/stripe');

exports.stripe_prepareSeatChangePayment = onCall(async (request) => {
  try {
    // ─────────────────── Validación básica ───────────────────
    assertAuth(request);
    const uid = String(request.auth.uid || '').trim();
    const data = request.data || {};
    const companyId = String(data.companyId || '').trim();
    const newQuantity = Number(data.newQuantity || 0);

    if (!companyId) {
      throw new HttpsError('invalid-argument', 'companyId requerido');
    }
    if (!Number.isInteger(newQuantity) || newQuantity < 1) {
      throw new HttpsError('invalid-argument', 'newQuantity inválido');
    }

    await assertCompanyAccount(uid, companyId);

    // ─────────────────── Cargar empresa ───────────────────
    const companySnap = await db.collection('companies').doc(companyId).get();
    if (!companySnap.exists) {
      throw new HttpsError('not-found', 'Empresa no existe');
    }

    const company = companySnap.data() || {};
    const subscriptionId = String(company.stripeSubscriptionId || '').trim();
    const customerIdFromCompany = String(company.stripeCustomerId || '').trim();

    if (!subscriptionId) {
      throw new HttpsError(
          'failed-precondition',
          'No hay suscripción Stripe asociada',
      );
    }

    const stripe = getStripe();
    const PRICE_ID = process.env.PRICE_ID;
    if (!PRICE_ID) {
      throw new HttpsError('failed-precondition', 'PRICE_ID no configurado');
    }

    // ─────────────────── Recuperar suscripción actual ───────────────────
    const currentSub = await stripe.subscriptions.retrieve(subscriptionId, {
      expand: ['items.data.price'],
    });

    if (!currentSub) {
      throw new HttpsError('not-found', 'Suscripción Stripe no encontrada');
    }

    logger.info('[prepareSeatChangePayment] current subscription', {
      companyId,
      subscriptionId: currentSub.id,
      status: currentSub.status,
    });

    const BLOCKED_UPDATE_STATUSES = [
      'incomplete',
      'incomplete_expired',
      'past_due',
      'unpaid',
    ];

    let updated;

    // ─────────────────── Caso 1: suscripción CANCELADA → crear una nueva ───────────────────
    if (currentSub.status === 'canceled') {
      const customerId =
        customerIdFromCompany ||
        (typeof currentSub.customer === 'string' ?
          currentSub.customer :
          currentSub.customer?.id);

      if (!customerId) {
        throw new HttpsError(
            'failed-precondition',
            'No se pudo determinar el cliente Stripe para reactivar la suscripción',
        );
      }

      logger.info('[prepareSeatChangePayment] creating NEW subscription', {
        companyId,
        customerId,
        newQuantity,
      });

      updated = await stripe.subscriptions.create({
        customer: customerId,
        items: [{ price: PRICE_ID, quantity: newQuantity },
        ],
        collection_method: 'charge_automatically',
        payment_behavior: 'default_incomplete',
        proration_behavior: 'always_invoice',
        // OJO: no usamos billing_cycle_anchor aquí
        expand: ['latest_invoice.payment_intent', 'customer'],
      });

      // Guardar nuevo subscriptionId en Firestore
      await updateCompanyMirror(companyId, {
        stripeSubscriptionId: updated.id,
        billingStatus: updated.status,
        currentPeriodEnd: updated.current_period_end,
      });
    } else {
      // ─────────────────── Caso 2: suscripción NO cancelada ───────────────────
      // Bloqueamos explícitamente estados que Stripe no deja tocar
      if (BLOCKED_UPDATE_STATUSES.includes(currentSub.status)) {
        throw new HttpsError(
            'failed-precondition',
            `No se puede modificar la suscripción porque está en estado '${currentSub.status}'. ` +
              'Primero resuelve el pago pendiente desde la pantalla de facturación.',
        );
      }

      if (!currentSub?.items?.data?.length) {
        throw new HttpsError(
            'internal',
            'No se encontró el item de suscripción en Stripe',
        );
      }

      const item = currentSub.items.data[0];

      logger.info('[prepareSeatChangePayment] updating subscription quantity', {
        companyId,
        subscriptionId: currentSub.id,
        itemId: item.id,
        oldQuantity: item.quantity,
        newQuantity,
      });

      updated = await stripe.subscriptions.update(currentSub.id, {
        payment_behavior: 'default_incomplete',
        proration_behavior: 'always_invoice',
        // NO usar billing_cycle_anchor: 'now'
        items: [{ id: item.id, quantity: newQuantity }],
        expand: ['latest_invoice.payment_intent', 'customer'],
      });
    }

    // ─────────────────── Preparar respuesta para PaymentSheet ───────────────────
    const invoice = updated.latest_invoice || null;
    const paymentIntent = invoice?.payment_intent || null;
    const invoiceId = invoice?.id || invoice || null;

    const newQty = updated.items.data[0].quantity;
    const amountCents = invoice ? invoice.total || 0 : 0;
    const currency = invoice ? invoice.currency || 'eur' : 'eur';
    const customerId =
      updated.customer && typeof updated.customer === 'object' ?
        updated.customer.id :
        updated.customer;

    // Si no hay PaymentIntent → importe 0€, no hay pago ahora
    if (!paymentIntent) {
      await updateCompanyMirror(companyId, {
        contractedSeats: newQty,
        billingStatus: updated.status,
        currentPeriodEnd: updated.current_period_end,
      });

      logger.info('[prepareSeatChangePayment] no payment required', {
        companyId,
        subscriptionId: updated.id,
        quantity: newQty,
      });

      return {
        ok: true,
        requiresPayment: false,
        customerId,
        ephemeralKeySecret: null,
        paymentIntentClientSecret: null,
        subscriptionId: updated.id,
        invoiceId,
        newQuantity: newQty,
        amountCents,
        currency,
      };
    }

    // Hay PaymentIntent → devolvemos secretos
    const eph = await stripe.ephemeralKeys.create(
        { customer: customerId },
        { apiVersion: '2024-06-20' },
    );

    logger.info('[prepareSeatChangePayment] payment required', {
      companyId,
      subscriptionId: updated.id,
      invoiceId,
      amountCents,
      currency,
    });

    return {
      ok: true,
      requiresPayment: true,
      customerId,
      ephemeralKeySecret: eph.secret,
      paymentIntentClientSecret: paymentIntent.client_secret,
      subscriptionId: updated.id,
      invoiceId,
      newQuantity: newQty,
      amountCents,
      currency,
    };
  } catch (err) {
    logger.error('[prepareSeatChangePayment] FAILED', {
      msg: err?.message || String(err),
      stack: err?.stack || null,
    });

    if (err instanceof HttpsError) {
      throw err;
    }

    throw new HttpsError('internal', err?.message || 'Error interno');
  }
});
