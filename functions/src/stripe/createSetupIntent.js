const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { db } = require('../config/firebase');
const { assertAuth, assertCompanyAccount } = require('../helpers/assertions');
const { getStripe } = require('../config/stripe');
const logger = require('firebase-functions/logger');

exports.stripe_createSetupIntent = onCall(async (request) => {
  try {
    assertAuth(request);
    const uid = String(request.auth.uid || '').trim();
    const { companyId } = request.data || {};
    if (!companyId) throw new HttpsError('invalid-argument', 'companyId requerido');
    await assertCompanyAccount(uid, companyId);

    const doc = await db.collection('companies').doc(companyId).get();
    if (!doc.exists) throw new HttpsError('not-found', 'Empresa no encontrada');
    const company = doc.data() || {};
    const customerId = company.stripeCustomerId;
    if (!customerId) throw new HttpsError('failed-precondition', 'Cliente Stripe no configurado');

    const stripe = getStripe();

    const setupIntent = await stripe.setupIntents.create({
      customer: customerId,
      payment_method_types: ['card'],
      usage: 'off_session',
    });

    const eph = await stripe.ephemeralKeys.create(
        { customer: customerId },
        { apiVersion: '2024-06-20' },
    );

    return {
      ok: true,
      customerId,
      ephemeralKeySecret: eph.secret,
      setupIntentClientSecret: setupIntent.client_secret,
    };
  } catch (err) {
    logger.error('[stripe_createSetupIntent] FAILED', err);
    if (err instanceof HttpsError) throw err;
    throw new HttpsError('internal', err.message);
  }
});
