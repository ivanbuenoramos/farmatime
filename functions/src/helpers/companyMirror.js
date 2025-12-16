// helpers/companyMirror.js
const { db, admin } = require('../config/firebase');
const { getStripe } = require('../config/stripe');

async function updateCompanyMirror(companyId, payload) {
  const data = { updatedAt: admin.firestore.FieldValue.serverTimestamp() };

  if ('stripeCustomerId' in payload) data.stripeCustomerId = payload.stripeCustomerId ?? null;
  if ('stripeSubscriptionId' in payload) data.stripeSubscriptionId = payload.stripeSubscriptionId ?? null;

  if ('pendingSeats' in payload) data.pendingSeats = payload.pendingSeats ?? null;

  if ('scheduledSeats' in payload) data.scheduledSeats = payload.scheduledSeats ?? null;
  if ('scheduledPaidSeats' in payload) data.scheduledPaidSeats = payload.scheduledPaidSeats ?? null;

  if ('scheduledForPeriodEnd' in payload) {
    // viene en unix seconds (number)
    data.scheduledForPeriodEnd =
      payload.scheduledForPeriodEnd ?
        admin.firestore.Timestamp.fromMillis(payload.scheduledForPeriodEnd * 1000) :
        null;
  }

  if ('contractedSeats' in payload && typeof payload.contractedSeats === 'number') {
    data.contractedSeats = payload.contractedSeats;
  }

  if ('billingStatus' in payload) data.billingStatus = payload.billingStatus ?? null;

  if ('currentPeriodEnd' in payload) {
    data.currentPeriodEnd =
      payload.currentPeriodEnd ?
        admin.firestore.Timestamp.fromMillis(payload.currentPeriodEnd * 1000) :
        null;
  }

  await db.collection('companies').doc(companyId).set(data, { merge: true });
}

async function getCompanyIdFromCustomer(customerId) {
  const q = await db.collection('companies').where('stripeCustomerId', '==', customerId).limit(1).get();
  if (!q.empty) return q.docs[0].id;

  const stripe = getStripe();
  const customer = await stripe.customers.retrieve(customerId);
  return (customer && customer.metadata && customer.metadata.companyId) || '';
}

module.exports = { updateCompanyMirror, getCompanyIdFromCustomer };
