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

    if (!companyId) throw new HttpsError('invalid-argument', 'companyId requerido');
    if (!Number.isInteger(newQuantity) || newQuantity < 1) {
      throw new HttpsError('invalid-argument', 'newQuantity inválido');
    }

    await assertCompanyAccount(uid, companyId);

    // Empresa y sub
    const doc = await db.collection('companies').doc(companyId).get();
    if (!doc.exists) throw new HttpsError('not-found', 'Empresa no existe');
    const company = doc.data() || {};
    const subscriptionId = String(company.stripeSubscriptionId || '').trim();
    if (!subscriptionId) {
      throw new HttpsError('failed-precondition', 'No hay suscripción Stripe asociada');
    }

    const stripe = getStripe();

    // Suscripción actual (con items)
    const sub = await stripe.subscriptions.retrieve(subscriptionId, {
      expand: ['items.data.price'],
    });
    if (!sub?.items?.data?.length) {
      throw new HttpsError('internal', 'No se encontró el item de suscripción');
    }
    const item = sub.items.data[0];

    // ⚠️ IMPORTANTE:
    // Actualizamos la suscripción con payment_behavior=default_incomplete para que Stripe
    // genere una invoice + (si hay importe) un PaymentIntent que exigirá PaymentSheet.
    // NO ESPEJAMOS NADA EN FIRESTORE AQUÍ.
    const updated = await stripe.subscriptions.update(sub.id, {
      payment_behavior: 'default_incomplete',
      proration_behavior: 'always_invoice',
      billing_cycle_anchor: 'now',
      items: [{ id: item.id, quantity: newQuantity }],
      expand: ['latest_invoice.payment_intent', 'customer'],
    });

    const invoice = updated.latest_invoice || null;
    const paymentIntent = invoice?.payment_intent || null;

    // Si NO hay PaymentIntent es porque el total es 0€ (no hay cargo ahora).
    // AÚN ASÍ no tocamos Firestore. El espejo de plazas solo se mueve en invoice.paid.
    if (!paymentIntent) {
      const newQty = updated.items.data[0].quantity;

      // ✅ Espejar en Firestore cuando NO hay cobro (total = 0)
      await updateCompanyMirror(companyId, {
        contractedSeats: newQty,
        billingStatus: updated.status,
        currentPeriodEnd: updated.current_period_end,
      });

      const customerId = updated.customer?.id ? updated.customer.id : updated.customer;
      return {
        ok: true,
        requiresPayment: false,
        customerId,
        ephemeralKeySecret: null,
        paymentIntentClientSecret: null,
        subscriptionId: updated.id,
        newQuantity: newQty,
        amountCents: invoice ? (invoice.total || 0) : 0,
        currency: invoice ? (invoice.currency || 'eur') : 'eur',
      };
    }

    // Hay PaymentIntent -> devolvemos secretos para PaymentSheet
    const customerId = updated.customer?.id ? updated.customer.id : updated.customer;
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
      newQuantity: updated.items.data[0].quantity,
      amountCents: invoice.total || 0,
      currency: invoice.currency || 'eur',
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
