const { db, admin } = require('../config/firebase');
const { getStripe } = require('../config/stripe');

async function updateCompanyMirror(companyId, payload) {
  const data = { updatedAt: admin.firestore.FieldValue.serverTimestamp() };
  if (payload.stripeCustomerId) data.stripeCustomerId = payload.stripeCustomerId;
  if (payload.stripeSubscriptionId) data.stripeSubscriptionId = payload.stripeSubscriptionId;
  if (typeof payload.contractedSeats === 'number') data.contractedSeats = payload.contractedSeats;
  if (payload.billingStatus) data.billingStatus = payload.billingStatus;
  if (payload.currentPeriodEnd) {
    data.currentPeriodEnd = admin.firestore.Timestamp.fromMillis(payload.currentPeriodEnd * 1000);
  }
  await db.collection('companies').doc(companyId).set(data, { merge: true });
}

async function getCompanyIdFromCustomer(customerId) {
  const q = await db
      .collection('companies')
      .where('stripeCustomerId', '==', customerId)
      .limit(1)
      .get();
  if (!q.empty) return q.docs[0].id;

  const stripe = getStripe();
  const customer = await stripe.customers.retrieve(customerId);
  return (customer && customer.metadata && customer.metadata.companyId) || '';
}

module.exports = { updateCompanyMirror, getCompanyIdFromCustomer };
