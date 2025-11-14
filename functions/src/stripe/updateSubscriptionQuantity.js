const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { db } = require('../config/firebase');
const { assertAuth, assertCompanyAccount } = require('../helpers/assertions');
const { updateCompanyMirror } = require('../helpers/companyMirror');
const { getStripe } = require('../config/stripe');

exports.stripe_updateSubscriptionQuantity = onCall(async (request) => {
  assertAuth(request);
  const uid = request.auth.uid;
  const data = request.data || {};

  const companyId = String(data.companyId || '');
  const quantity = Number(data.quantity || 1);
  const prorationBehaviorRaw = String(data.proration_behavior || '');
  const prorationBehavior =
    prorationBehaviorRaw === 'none' ? 'none' : 'create_prorations';

  if (!companyId) throw new HttpsError('invalid-argument', 'companyId requerido');
  if (!Number.isInteger(quantity) || quantity <= 0) {
    throw new HttpsError('invalid-argument', 'quantity inválido');
  }

  assertCompanyAccount(uid, companyId);

  const snap = await db.collection('companies').doc(companyId).get();
  const company = snap.data() || {};
  if (!company.stripeSubscriptionId) {
    throw new HttpsError('failed-precondition', 'No hay suscripción Stripe');
  }

  const stripe = getStripe();
  const subscription = await stripe.subscriptions.retrieve(company.stripeSubscriptionId);
  const itemId = subscription.items.data[0].id;

  const updatedItem = await stripe.subscriptionItems.update(itemId, {
    quantity,
    proration_behavior: prorationBehavior,
  });

  const subAfter = await stripe.subscriptions.retrieve(subscription.id);

  await updateCompanyMirror(companyId, {
    contractedSeats: updatedItem.quantity ?? quantity,
    billingStatus: subAfter.status,
    currentPeriodEnd: subAfter.current_period_end,
  });

  return { ok: true, quantity: updatedItem.quantity };
});

