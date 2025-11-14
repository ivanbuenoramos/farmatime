const { HttpsError } = require('firebase-functions/v2/https');
let _stripe = null;

function getStripe() {
  if (_stripe) return _stripe;
  const Stripe = require('stripe');
  const key = process.env.STRIPE_SECRET || '';
  if (!key) throw new HttpsError('failed-precondition', 'STRIPE_SECRET no configurado');
  _stripe = new Stripe(key, { apiVersion: '2024-06-20' });
  return _stripe;
}

module.exports = { getStripe };
