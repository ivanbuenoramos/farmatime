const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { db } = require('../config/firebase');
const { assertAuth, assertCompanyAccount } = require('../helpers/assertions');
const { getStripe } = require('../config/stripe');
const logger = require('firebase-functions/logger');

exports.stripe_setDefaultPaymentMethod = onCall(async (request) => {
  try {
    assertAuth(request);
    const uid = String(request.auth.uid || '').trim();
    const { companyId, paymentMethodId } = request.data || {};

    if (!companyId || !paymentMethodId) {
      throw new HttpsError('invalid-argument', 'Faltan parámetros');
    }

    await assertCompanyAccount(uid, companyId);

    const doc = await db.collection('companies').doc(companyId).get();
    if (!doc.exists) throw new HttpsError('not-found', 'Empresa no encontrada');
    const company = doc.data() || {};
    const customerId = company.stripeCustomerId;

    const stripe = getStripe();
    await stripe.customers.update(customerId, {
      invoice_settings: { default_payment_method: paymentMethodId },
    });

    return { ok: true };
  } catch (err) {
    logger.error('[stripe_setDefaultPaymentMethod] FAILED', err);
    if (err instanceof HttpsError) throw err;
    throw new HttpsError('internal', err.message);
  }
});
