const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { db } = require('../config/firebase');
const { assertAuth, assertCompanyAccount } = require('../helpers/assertions');
const { updateCompanyMirror } = require('../helpers/companyMirror');
const { getStripe } = require('../config/stripe');

exports.stripe_createCustomerAndSubscription = onCall(async (request) => {
  assertAuth(request);
  const uid = request.auth.uid;
  const data = request.data || {};
  const companyId = String(data.companyId || '');
  const initialQuantity = Number(data.initialQuantity || 1);

  if (!companyId) throw new HttpsError('invalid-argument', 'companyId requerido');
  if (!Number.isInteger(initialQuantity) || initialQuantity <= 0) {
    throw new HttpsError('invalid-argument', 'initialQuantity inválido');
  }

  await assertCompanyAccount(uid, companyId);

  const PRICE_ID = process.env.PRICE_ID;
  if (!PRICE_ID) throw new HttpsError('failed-precondition', 'PRICE_ID no configurado');

  const companyRef = db.collection('companies').doc(companyId);
  const snap = await companyRef.get();
  if (!snap.exists) throw new HttpsError('not-found', 'Empresa no existe');
  const c = snap.data() || {};

  const stripe = getStripe();
  const customer = await stripe.customers.create({
    email: c.email || undefined,
    metadata: { companyId },
  });
  const subscription = await stripe.subscriptions.create({
    customer: customer.id,
    items: [{ price: PRICE_ID, quantity: initialQuantity }],
    collection_method: 'charge_automatically',
  });

  await updateCompanyMirror(companyId, {
    stripeCustomerId: customer.id,
    stripeSubscriptionId: subscription.id,
    contractedSeats: initialQuantity,
    billingStatus: subscription.status,
    currentPeriodEnd: subscription.current_period_end,
  });

  return { ok: true, subscriptionId: subscription.id };
});
