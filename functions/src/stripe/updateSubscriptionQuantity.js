const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { db } = require('../config/firebase');
const { assertAuth, assertCompanyAccount } = require('../helpers/assertions');
const { updateCompanyMirror } = require('../helpers/companyMirror');
const { getStripe } = require('../config/stripe');

exports.stripe_updateSubscriptionQuantity = onCall(async (request) => {
  assertAuth(request);
  const uid = request.auth.uid;
  const data = request.data || {};

  const companyId = String(data.companyId || '').trim();
  const totalSeats = Number(data.totalSeats || 1); // 👈 antes quantity
  const prorationBehaviorRaw = String(data.proration_behavior || '').trim();
  const prorationBehavior = prorationBehaviorRaw === 'none' ? 'none' : 'create_prorations';

  if (!companyId) throw new HttpsError('invalid-argument', 'companyId requerido');
  if (!Number.isInteger(totalSeats) || totalSeats < 1) {
    throw new HttpsError('invalid-argument', 'totalSeats inválido');
  }

  await assertCompanyAccount(uid, companyId);

  const snap = await db.collection('companies').doc(companyId).get();
  if (!snap.exists) throw new HttpsError('not-found', 'Empresa no encontrada');

  const company = snap.data() || {};

  const subscriptionId = String(company.stripeSubscriptionId || '').trim();
  if (!subscriptionId) {
    throw new HttpsError('failed-precondition', 'No hay suscripción Stripe');
  }

  const stripe = getStripe();
  const subscription = await stripe.subscriptions.retrieve(subscriptionId);

  if (!subscription?.items?.data?.length) {
    throw new HttpsError('internal', 'No se encontró el item de suscripción');
  }

  const item = subscription.items.data[0];
  const currentPaidQty = item.quantity ?? 0;
  const currentTotalSeats = currentPaidQty + 1;

  // Solo permitir BAJAR totalSeats aquí
  if (totalSeats > currentTotalSeats) {
    throw new HttpsError(
        'failed-precondition',
        'No se permite aumentar plazas con esta función. Usa stripe_prepareSeatChangePayment.',
    );
  }

  const newPaidQty = Math.max(totalSeats - 1, 0);

  // Si se queda en 1 total => sin suscripción
  if (newPaidQty === 0) {
    await stripe.subscriptions.cancel(subscription.id);

    await updateCompanyMirror(companyId, {
      stripeSubscriptionId: null,
      contractedSeats: 1,
      billingStatus: 'none',
      currentPeriodEnd: null,
    });

    return { ok: true, totalSeats: 1, paidSeats: 0, canceled: true };
  }

  const updatedItem = await stripe.subscriptionItems.update(item.id, {
    quantity: newPaidQty,
    proration_behavior: prorationBehavior,
  });

  const subAfter = await stripe.subscriptions.retrieve(subscription.id);

  await updateCompanyMirror(companyId, {
    contractedSeats: (updatedItem.quantity ?? newPaidQty) + 1, // 👈 total seats
    billingStatus: subAfter.status,
    currentPeriodEnd: subAfter.current_period_end,
  });

  return {
    ok: true,
    totalSeats: (updatedItem.quantity ?? newPaidQty) + 1,
    paidSeats: updatedItem.quantity ?? newPaidQty,
  };
});
