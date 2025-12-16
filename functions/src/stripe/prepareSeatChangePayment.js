const { onCall, HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');

const { db } = require('../config/firebase');
const { assertAuth, assertCompanyAccount } = require('../helpers/assertions');
const { updateCompanyMirror } = require('../helpers/companyMirror');
const { getStripe } = require('../config/stripe');

exports.stripe_prepareSeatChangePayment = onCall(async (request) => {
  try {
    assertAuth(request);
    const uid = String(request.auth.uid || '').trim();
    const data = request.data || {};

    const companyId = String(data.companyId || '').trim();
    const newTotalSeats = Number(data.newTotalSeats ?? 1);

    if (!companyId) throw new HttpsError('invalid-argument', 'companyId requerido');
    if (!Number.isInteger(newTotalSeats) || newTotalSeats < 1) {
      throw new HttpsError('invalid-argument', 'newTotalSeats inválido');
    }

    await assertCompanyAccount(uid, companyId);

    const companyRef = db.collection('companies').doc(companyId);
    const companySnap = await companyRef.get();
    if (!companySnap.exists) throw new HttpsError('not-found', 'Empresa no existe');

    const company = companySnap.data() || {};
    const customerId = String(company.stripeCustomerId || '').trim();
    const subscriptionId = String(company.stripeSubscriptionId || '').trim();

    if (!customerId) {
      throw new HttpsError('failed-precondition', 'No hay cliente Stripe asociado');
    }

    const stripe = getStripe();
    const PRICE_ID = process.env.PRICE_ID;
    if (!PRICE_ID) throw new HttpsError('failed-precondition', 'PRICE_ID no configurado');

    const currentContracted = Number.isInteger(company.contractedSeats) && company.contractedSeats >= 1 ?
      company.contractedSeats :
      1;

    const currentTotalSeats = currentContracted; // total (incluye gratis)
    const newPaidSeats = Math.max(newTotalSeats - 1, 0); // quantity Stripe

    // ───────────────────────────────────────────────────────────────
    // (A) BAJAR ASIENTOS → NO TOCAR STRIPE AHORA (sin prorrateo)
    //     Se programa para la siguiente renovación
    // ───────────────────────────────────────────────────────────────
    if (newTotalSeats < currentTotalSeats) {
      // Sin suscripción, no hay nada que programar
      if (!subscriptionId) {
        await updateCompanyMirror(companyId, {
          contractedSeats: 1,
          billingStatus: 'none',
          currentPeriodEnd: null,
          pendingSeats: null,
          scheduledSeats: null,
          scheduledPaidSeats: null,
          scheduledForPeriodEnd: null,
        });

        return {
          ok: true,
          requiresPayment: false,
          mode: 'downgrade_no_subscription',
          newTotalSeats: 1,
          newPaidSeats: 0,
          amountCents: 0,
          currency: 'eur',
          customerId,
          subscriptionId: null,
          invoiceId: null,
          ephemeralKeySecret: null,
          paymentIntentClientSecret: null,
        };
      }

      // Necesitamos saber para qué ciclo se programa: usamos currentPeriodEnd de Stripe
      const sub = await stripe.subscriptions.retrieve(subscriptionId, { expand: ['items.data'] });

      await updateCompanyMirror(companyId, {
        // OJO: contractedSeats NO cambia ahora. Sigues pagando lo actual hasta fin de ciclo.
        billingStatus: sub.status,
        currentPeriodEnd: sub.current_period_end,
        pendingSeats: null, // si había algo pendiente, lo anulamos
        scheduledSeats: newTotalSeats,
        scheduledPaidSeats: newPaidSeats,
        scheduledForPeriodEnd: sub.current_period_end, // “aplicar en la próxima”
      });

      return {
        ok: true,
        requiresPayment: false,
        mode: 'downgrade_scheduled',
        newTotalSeats,
        newPaidSeats,
        amountCents: 0,
        currency: 'eur',
        customerId,
        subscriptionId,
        invoiceId: null,
        ephemeralKeySecret: null,
        paymentIntentClientSecret: null,
      };
    }

    // ───────────────────────────────────────────────────────────────
    // (B) MISMO Nº ASIENTOS → nada que hacer
    // ───────────────────────────────────────────────────────────────
    if (newTotalSeats === currentTotalSeats) {
      return {
        ok: true,
        requiresPayment: false,
        mode: 'no_change',
        newTotalSeats,
        newPaidSeats,
        amountCents: 0,
        currency: 'eur',
        customerId,
        subscriptionId: subscriptionId || null,
        invoiceId: null,
        ephemeralKeySecret: null,
        paymentIntentClientSecret: null,
      };
    }

    // ───────────────────────────────────────────────────────────────
    // (C) SUBIR ASIENTOS → PRORRATEO + PAGO OBLIGATORIO
    //     NO confirmamos contractedSeats hasta invoice.paid
    // ───────────────────────────────────────────────────────────────

    // Subir a 1 (solo gratis) no tiene sentido aquí (porque newTotalSeats > currentTotalSeats)
    // pero lo dejamos por seguridad.
    if (newPaidSeats === 0) {
      // Cancelaría suscripción, pero esto es “bajar”, no subir.
      return {
        ok: true,
        requiresPayment: false,
        mode: 'upgrade_to_free_ignored',
        newTotalSeats: 1,
        newPaidSeats: 0,
        amountCents: 0,
        currency: 'eur',
        customerId,
        subscriptionId: subscriptionId || null,
        invoiceId: null,
        ephemeralKeySecret: null,
        paymentIntentClientSecret: null,
      };
    }

    // Si NO hay suscripción todavía → crear nueva incomplete con PI
    if (!subscriptionId) {
      logger.info('[prepareSeatChangePayment] create subscription (upgrade)', {
        companyId,
        customerId,
        newPaidSeats,
        newTotalSeats,
      });

      const created = await stripe.subscriptions.create({
        customer: customerId,
        items: [{ price: PRICE_ID, quantity: newPaidSeats }],
        collection_method: 'charge_automatically',
        payment_behavior: 'default_incomplete',
        proration_behavior: 'always_invoice',
        metadata: { companyId },
        expand: ['latest_invoice.payment_intent', 'customer', 'items.data'],
      });

      const invoice = created.latest_invoice || null;
      const paymentIntent = invoice?.payment_intent || null;

      if (!paymentIntent) {
        // Muy raro en upgrade, pero si no hay pago, aplicamos y listo
        await updateCompanyMirror(companyId, {
          stripeSubscriptionId: created.id,
          billingStatus: created.status,
          currentPeriodEnd: created.current_period_end,
          contractedSeats: newTotalSeats,
          pendingSeats: null,
          scheduledSeats: null,
          scheduledPaidSeats: null,
          scheduledForPeriodEnd: null,
        });

        return {
          ok: true,
          requiresPayment: false,
          mode: 'upgrade_no_payment_required',
          customerId,
          subscriptionId: created.id,
          invoiceId: invoice?.id || null,
          newTotalSeats,
          newPaidSeats,
          amountCents: invoice?.total || 0,
          currency: invoice?.currency || 'eur',
          ephemeralKeySecret: null,
          paymentIntentClientSecret: null,
        };
      }

      await updateCompanyMirror(companyId, {
        stripeSubscriptionId: created.id,
        billingStatus: created.status, // incomplete
        currentPeriodEnd: created.current_period_end,
        pendingSeats: newTotalSeats,
        // NO tocamos contractedSeats todavía
        scheduledSeats: null,
        scheduledPaidSeats: null,
        scheduledForPeriodEnd: null,
      });

      const eph = await stripe.ephemeralKeys.create(
          { customer: customerId },
          { apiVersion: '2024-06-20' },
      );

      return {
        ok: true,
        requiresPayment: true,
        mode: 'upgrade_payment_required',
        customerId,
        subscriptionId: created.id,
        invoiceId: invoice?.id || null,
        newTotalSeats,
        newPaidSeats,
        amountCents: invoice?.total || 0,
        currency: invoice?.currency || 'eur',
        ephemeralKeySecret: eph.secret,
        paymentIntentClientSecret: paymentIntent.client_secret,
      };
    }

    // Hay suscripción → update quantity con prorrateo + PI
    const currentSub = await stripe.subscriptions.retrieve(subscriptionId, {
      expand: ['items.data.price', 'latest_invoice.payment_intent', 'customer'],
    });

    // Si está past_due/unpaid/incomplete, NO usamos esto para “reintentar”
    // porque ese flujo debe ir por stripe_getOpenInvoicePayment / portal
    const BLOCKED = ['incomplete', 'incomplete_expired', 'past_due', 'unpaid'];
    if (BLOCKED.includes(currentSub.status)) {
      throw new HttpsError(
          'failed-precondition',
          `No se puede aumentar plazas porque la suscripción está en estado '${currentSub.status}'. ` +
            'Primero resuelve el pago pendiente.',
      );
    }

    if (!currentSub?.items?.data?.length) {
      throw new HttpsError('internal', 'No se encontró el item de suscripción');
    }

    const item = currentSub.items.data[0];

    logger.info('[prepareSeatChangePayment] update subscription (upgrade)', {
      companyId,
      subscriptionId,
      oldQty: item.quantity,
      newPaidSeats,
      newTotalSeats,
    });

    const updated = await stripe.subscriptions.update(subscriptionId, {
      payment_behavior: 'default_incomplete',
      proration_behavior: 'always_invoice',
      items: [{ id: item.id, quantity: newPaidSeats }],
      expand: ['latest_invoice.payment_intent', 'customer', 'items.data'],
    });

    const invoice = updated.latest_invoice || null;
    const paymentIntent = invoice?.payment_intent || null;

    if (!paymentIntent) {
      // Si no hay PI, aplicamos sin pago
      await updateCompanyMirror(companyId, {
        billingStatus: updated.status,
        currentPeriodEnd: updated.current_period_end,
        contractedSeats: newTotalSeats,
        pendingSeats: null,
        scheduledSeats: null,
        scheduledPaidSeats: null,
        scheduledForPeriodEnd: null,
      });

      return {
        ok: true,
        requiresPayment: false,
        mode: 'upgrade_no_payment_required',
        customerId,
        subscriptionId: updated.id,
        invoiceId: invoice?.id || null,
        newTotalSeats,
        newPaidSeats,
        amountCents: invoice?.total || 0,
        currency: invoice?.currency || 'eur',
        ephemeralKeySecret: null,
        paymentIntentClientSecret: null,
      };
    }

    // ✅ pago obligatorio: pendingSeats y nada más
    await updateCompanyMirror(companyId, {
      billingStatus: updated.status, // incomplete
      currentPeriodEnd: updated.current_period_end,
      pendingSeats: newTotalSeats,
      // NO tocamos contractedSeats todavía
    });

    const eph = await stripe.ephemeralKeys.create(
        { customer: customerId },
        { apiVersion: '2024-06-20' },
    );

    return {
      ok: true,
      requiresPayment: true,
      mode: 'upgrade_payment_required',
      customerId,
      subscriptionId: updated.id,
      invoiceId: invoice?.id || null,
      newTotalSeats,
      newPaidSeats,
      amountCents: invoice?.total || 0,
      currency: invoice?.currency || 'eur',
      ephemeralKeySecret: eph.secret,
      paymentIntentClientSecret: paymentIntent.client_secret,
    };
  } catch (err) {
    logger.error('[stripe_prepareSeatChangePayment] FAILED', {
      msg: err?.message || String(err),
      stack: err?.stack || null,
    });

    if (err instanceof HttpsError) throw err;
    throw new HttpsError('internal', err?.message || 'Error interno');
  }
});
