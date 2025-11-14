const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { db } = require('../config/firebase');
const { assertAuth, assertCompanyAccount } = require('../helpers/assertions');
const { getStripe } = require('../config/stripe');
const logger = require('firebase-functions/logger');

exports.stripe_listPaymentMethods = onCall(async (request) => {
  try {
    assertAuth(request);
    const uid = String(request.auth.uid || '').trim();
    const { companyId } = request.data || {};

    if (!companyId) throw new HttpsError('invalid-argument', 'companyId requerido');
    await assertCompanyAccount(uid, companyId);

    const doc = await db.collection('companies').doc(companyId).get();
    if (!doc.exists) throw new HttpsError('not-found', 'Empresa no encontrada');
    const company = doc.data() || {};

    const stripe = getStripe();
    const customerId = company.stripeCustomerId;
    if (!customerId) throw new HttpsError('failed-precondition', 'Cliente Stripe no configurado');

    const customer = await stripe.customers.retrieve(customerId);
    const defaultPmId = customer.invoice_settings?.default_payment_method || null;

    const pms = await stripe.paymentMethods.list({
      customer: customerId,
      type: 'card',
    });

    const result = pms.data.map((pm) => ({
      id: pm.id,
      brand: pm.card?.brand || 'unknown',
      last4: pm.card?.last4 || '',
      expMonth: pm.card?.exp_month || 0,
      expYear: pm.card?.exp_year || 0,
      isDefault: pm.id === defaultPmId,
    }));

    return { ok: true, paymentMethods: result };
  } catch (err) {
    logger.error('[stripe_listPaymentMethods] FAILED', err);
    if (err instanceof HttpsError) throw err;
    throw new HttpsError('internal', err.message);
  }
});
