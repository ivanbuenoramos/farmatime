const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { assertAuth, assertCompanyAccount } = require('../helpers/assertions');
const { getStripe } = require('../config/stripe');
const logger = require('firebase-functions/logger');

exports.stripe_detachPaymentMethod = onCall(async (request) => {
  try {
    assertAuth(request);
    const uid = String(request.auth.uid || '').trim();
    const { companyId, paymentMethodId } = request.data || {};

    if (!companyId || !paymentMethodId) {
      throw new HttpsError('invalid-argument', 'Faltan parámetros');
    }
    await assertCompanyAccount(uid, companyId);

    const stripe = getStripe();
    await stripe.paymentMethods.detach(paymentMethodId);

    return { ok: true };
  } catch (err) {
    logger.error('[stripe_detachPaymentMethod] FAILED', err);
    if (err instanceof HttpsError) throw err;
    throw new HttpsError('internal', err.message);
  }
});
