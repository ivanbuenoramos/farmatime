const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { db } = require('../config/firebase');
const { assertAuth, assertCompanyAccount } = require('../helpers/assertions');
const { updateCompanyMirror } = require('../helpers/companyMirror');
const { getStripe } = require('../config/stripe');
const logger = require('firebase-functions/logger');

exports.stripe_prepareSeatChangePayment = onCall(async (request) => {
  try {
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

    // Empresa y suscripción
    const doc = await db.collection('companies').doc(companyId).get();
    if (!doc.exists) {
      throw new HttpsError('not-found', 'Empresa no existe');
    }

    const company = doc.data() || {};
    const subscriptionId = String(company.stripeSubscriptionId || '').trim();
    const customerIdFromCompany = String(company.stripeCustomerId || '').trim();

    if (!subscriptionId) {
      throw new HttpsError('failed-precondition', 'No hay suscripción Stripe asociada');
    }

    const stripe = getStripe();

    const PRICE_ID = process.env.PRICE_ID;
    if (!PRICE_ID) {
      throw new HttpsError('failed-precondition', 'PRICE_ID no configurado');
    }

    // 1) Recuperar suscripción actual
    const currentSub = await stripe.subscriptions.retrieve(subscriptionId, {
      expand: ['items.data.price'],
    });

    if (!currentSub) {
      throw new HttpsError('not-found', 'Suscripción Stripe no encontrada');
    }

    let updated;

    // ⚠️ Caso especial: la suscripción está CANCELADA → creamos una nueva
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

      updated = await stripe.subscriptions.create({
        customer: customerId,
        items: [{ price: PRICE_ID, quantity: newQuantity }],
        collection_method: 'charge_automatically',
        payment_behavior: 'default_incomplete',
        proration_behavior: 'always_invoice',
        // 🔴 OJO: NO usamos billing_cycle_anchor aquí
        expand: ['latest_invoice.payment_intent', 'customer'],
      });

      // Guardamos nuevo subscriptionId en Firestore
      await updateCompanyMirror(companyId, {
        stripeSubscriptionId: updated.id,
        billingStatus: updated.status,
        currentPeriodEnd: updated.current_period_end,
      });
    } else {
      // ✅ Caso normal: sub activa/trialing/past_due → actualizamos quantity
      if (!currentSub?.items?.data?.length) {
        throw new HttpsError('internal', 'No se encontró el item de suscripción');
      }

      const item = currentSub.items.data[0];

      updated = await stripe.subscriptions.update(currentSub.id, {
        payment_behavior: 'default_incomplete',
        proration_behavior: 'always_invoice',
        // 🔴 NO billing_cycle_anchor: 'now'
        items: [{ id: item.id, quantity: newQuantity }],
        expand: ['latest_invoice.payment_intent', 'customer'],
      });
    }

    const invoice = updated.latest_invoice || null;
    const paymentIntent = invoice?.payment_intent || null;
    const invoiceId = invoice?.id || invoice || null;

    // ⚙️ Datos básicos para la respuesta
    const newQty = updated.items.data[0].quantity;
    const amountCents = invoice ? (invoice.total || 0) : 0;
    const currency = invoice ? (invoice.currency || 'eur') : 'eur';
    const customerId =
      updated.customer?.id ? updated.customer.id : updated.customer;

    // Si NO hay PaymentIntent es porque el total es 0€ (no hay cargo ahora).
    if (!paymentIntent) {
      // Aquí SÍ espejamos plazas porque no hay cobro
      await updateCompanyMirror(companyId, {
        contractedSeats: newQty,
        billingStatus: updated.status,
        currentPeriodEnd: updated.current_period_end,
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

    // Hay PaymentIntent → devolvemos secretos para PaymentSheet
    const eph = await stripe.ephemeralKeys.create(
        { customer: customerId },
        { apiVersion: '2024-06-20' },
    );

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
    if (err instanceof HttpsError) throw err;
    throw new HttpsError('internal', err?.message || 'Error interno');
  }
});
