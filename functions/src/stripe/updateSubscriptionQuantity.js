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
  const quantity = Number(data.quantity || 1);
  const prorationBehaviorRaw = String(data.proration_behavior || '').trim();
  const prorationBehavior =
    prorationBehaviorRaw === 'none' ? 'none' : 'create_prorations';

  if (!companyId) {
    throw new HttpsError('invalid-argument', 'companyId requerido');
  }
  if (!Number.isInteger(quantity) || quantity <= 0) {
    throw new HttpsError('invalid-argument', 'quantity inválido');
  }

  await assertCompanyAccount(uid, companyId);

  const snap = await db.collection('companies').doc(companyId).get();
  if (!snap.exists) {
    throw new HttpsError('not-found', 'Empresa no encontrada');
  }

  const company = snap.data() || {};
  if (!company.stripeSubscriptionId) {
    throw new HttpsError('failed-precondition', 'No hay suscripción Stripe');
  }

  const stripe = getStripe();

  const subscription = await stripe.subscriptions.retrieve(company.stripeSubscriptionId);
  if (!subscription?.items?.data?.length) {
    throw new HttpsError('internal', 'No se encontró el item de suscripción');
  }

  const item = subscription.items.data[0];
  const currentQty = item.quantity ?? 1;

  // 👇 IMPORTANTE: no permitir subir plazas con esta función
  if (quantity > currentQty) {
    throw new HttpsError(
        'failed-precondition',
        'No se permite aumentar plazas con esta función. Usa stripe_prepareSeatChangePayment.',
    );
  }

  const updatedItem = await stripe.subscriptionItems.update(item.id, {
    quantity,
    proration_behavior: prorationBehavior,
  });

  const subAfter = await stripe.subscriptions.retrieve(subscription.id);

  await updateCompanyMirror(companyId, {
    contractedSeats: updatedItem.quantity ?? quantity,
    billingStatus: subAfter.status,
    currentPeriodEnd: subAfter.current_period_end,
  });

  return {
    ok: true,
    quantity: updatedItem.quantity,
  };
});
