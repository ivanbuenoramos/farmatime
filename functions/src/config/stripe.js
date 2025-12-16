const Stripe = require('stripe');
const { defineSecret } = require('firebase-functions/params');

const STRIPE_SECRET_KEY = defineSecret('STRIPE_SECRET_KEY');
let client = null;

function getStripe() {
  if (client) return client;

  const key = STRIPE_SECRET_KEY.value();
  if (!key) throw new Error('Missing STRIPE_SECRET_KEY');

  client = new Stripe(key, { apiVersion: '2024-06-20' });
  return client;
}

module.exports = { getStripe, STRIPE_SECRET_KEY };
