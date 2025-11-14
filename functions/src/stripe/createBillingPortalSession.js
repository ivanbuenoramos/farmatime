const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { db } = require('../config/firebase');
const { assertAuth, assertCompanyAccount } = require('../helpers/assertions');
const { getStripe } = require('../config/stripe');
const logger = require('firebase-functions/logger');

exports.stripe_createBillingPortalSession = onCall(async (request) => {
  try {
    assertAuth(request);
    const uid = request.auth.uid;
    const data = request.data || {};

    const companyId = String(data.companyId || '');
    const returnUrl = String(data.returnUrl || '');

    if (!companyId) throw new HttpsError('invalid-argument', 'companyId requerido');
    assertCompanyAccount(uid, companyId);

    const snap = await db.collection('companies').doc(companyId).get();
    if (!snap.exists) throw new HttpsError('not-found', 'Empresa no existe');
    const c = snap.data() || {};

    const customerId = (c.stripeCustomerId || '').toString();
    if (!customerId) {
      throw new HttpsError('failed-precondition', 'No hay cliente Stripe asignado');
    }

    const stripe = getStripe();

    const session = await stripe.billingPortal.sessions.create({
      customer: customerId,
      return_url: returnUrl || 'https://yourapp.example.com',
    });

    return { ok: true, url: session.url };
  } catch (err) {
    logger.error('billingPortal error', { err });
    if (err instanceof HttpsError) throw err;
    const msg = (err && err.message) ? err.message : 'Error desconocido';
    throw new HttpsError('internal', `Stripe portal: ${msg}`);
  }
});
