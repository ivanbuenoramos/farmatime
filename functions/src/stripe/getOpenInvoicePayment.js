const { onCall, HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');

const { db } = require('../config/firebase');
const { getStripe } = require('../config/stripe');
const { assertAuth, assertCompanyAccount } = require('../helpers/assertions');

exports.stripe_getOpenInvoicePayment = onCall(async (request) => {
  try {
    assertAuth(request);
    const uid = String(request.auth.uid || '').trim();
    const data = request.data || {};
    const companyId = String(data.companyId || '').trim();

    if (!companyId) throw new HttpsError('invalid-argument', 'companyId requerido');
    await assertCompanyAccount(uid, companyId);

    const doc = await db.collection('companies').doc(companyId).get();
    if (!doc.exists) throw new HttpsError('not-found', 'Empresa no existe');

    const company = doc.data() || {};
    const customerId = String(company.stripeCustomerId || '').trim();
    const subscriptionId = String(company.stripeSubscriptionId || '').trim();

    if (!customerId) {
      throw new HttpsError('failed-precondition', 'Cliente Stripe no configurado');
    }

    const stripe = getStripe();

    // 1) Intento: si hay subscription, buscar invoices abiertos de esa subscription
    let invoice = null;

    if (subscriptionId) {
      const invList = await stripe.invoices.list({
        customer: customerId,
        subscription: subscriptionId,
        status: 'open',
        limit: 1,
      });
      invoice = invList.data?.[0] || null;
    }

    // 2) Fallback: último invoice abierto del customer
    if (!invoice) {
      const invList = await stripe.invoices.list({
        customer: customerId,
        status: 'open',
        limit: 1,
      });
      invoice = invList.data?.[0] || null;
    }

    if (!invoice) {
      return {
        hasOpenInvoice: false,
        customerId,
        billingStatus: company.billingStatus || null,
      };
    }

    // Asegurar PI expandido
    const inv = await stripe.invoices.retrieve(invoice.id, {
      expand: ['payment_intent'],
    });

    const pi = inv.payment_intent;
    if (!pi || typeof pi !== 'object' || !pi.client_secret) {
      // Sin PI: no podemos cobrar desde app -> Billing portal
      return {
        hasOpenInvoice: true,
        requiresPayment: false,
        customerId,
        billingStatus: company.billingStatus || null,
        invoiceId: inv.id,
        amountCents: inv.total || 0,
        currency: inv.currency || 'eur',
        reason: 'missing_payment_intent',
      };
    }

    const eph = await stripe.ephemeralKeys.create(
        { customer: customerId },
        { apiVersion: '2024-06-20' },
    );

    return {
      hasOpenInvoice: true,
      requiresPayment: true,
      customerId,
      ephemeralKeySecret: eph.secret,
      paymentIntentClientSecret: pi.client_secret,
      invoiceId: inv.id,
      amountCents: inv.total || 0,
      currency: inv.currency || 'eur',
      billingStatus: company.billingStatus || null,
    };
  } catch (err) {
    logger.error('[stripe_getOpenInvoicePayment] FAILED', {
      msg: err?.message || String(err),
      stack: err?.stack || null,
    });

    if (err instanceof HttpsError) throw err;
    throw new HttpsError('internal', err?.message || 'Error interno');
  }
});
