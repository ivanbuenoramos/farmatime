// src/stripe/stripe_getIncompletePayment.js

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');

const { db } = require('../config/firebase');
const { getStripe } = require('../config/stripe');
const { assertAuth, assertCompanyAccount } = require('../helpers/assertions');

exports.stripe_getIncompletePayment = onCall(async (request) => {
  try {
    // 1) Auth básica
    assertAuth(request);
    const uid = String(request.auth.uid || '').trim();

    const data = request.data || {};
    const companyId = String(data.companyId || '').trim();

    if (!companyId) {
      throw new HttpsError('invalid-argument', 'companyId requerido');
    }

    // 2) Verificar que el usuario pertenece a esa empresa
    await assertCompanyAccount(uid, companyId);

    // 3) Leer la empresa
    const doc = await db.collection('companies').doc(companyId).get();
    if (!doc.exists) {
      throw new HttpsError('not-found', 'Empresa no existe');
    }

    const company = doc.data() || {};
    const subscriptionId = String(company.stripeSubscriptionId || '').trim();
    const stripeCustomerId = String(company.stripeCustomerId || '').trim();

    if (!subscriptionId) {
      // No hay sub -> no hay pago incompleto
      return {
        hasIncomplete: false,
        billingStatus: company.billingStatus || null,
      };
    }

    const stripe = getStripe();

    // 4) Recuperar suscripción + último invoice + payment_intent
    const sub = await stripe.subscriptions.retrieve(subscriptionId, {
      expand: ['latest_invoice.payment_intent', 'customer'],
    });

    logger.info('[getIncompletePayment] subscription', {
      companyId,
      subId: sub.id,
      status: sub.status,
    });

    // Si no está en estado incomplete, salimos
    if (sub.status !== 'incomplete') {
      return {
        hasIncomplete: false,
        billingStatus: sub.status,
      };
    }

    const invoice = sub.latest_invoice;
    const paymentIntent = invoice && invoice.payment_intent;

    if (!invoice || !paymentIntent) {
      // No hay PI pendiente -> nada que cobrar desde app
      return {
        hasIncomplete: false,
        billingStatus: sub.status,
      };
    }

    // 5) Determinar customerId
    const customerId =
      stripeCustomerId ||
      (typeof sub.customer === 'string' ?
        sub.customer :
        sub.customer?.id);

    if (!customerId) {
      throw new HttpsError(
          'failed-precondition',
          'No se pudo determinar el cliente Stripe.',
      );
    }

    // 6) Crear ephemeral key para PaymentSheet
    const eph = await stripe.ephemeralKeys.create(
        { customer: customerId },
        { apiVersion: '2024-06-20' },
    );

    const amountCents = invoice.total || 0;
    const currency = invoice.currency || 'eur';

    return {
      hasIncomplete: true,
      billingStatus: sub.status,
      customerId,
      ephemeralKeySecret: eph.secret,
      paymentIntentClientSecret: paymentIntent.client_secret,
      amountCents,
      currency,
      invoiceId: invoice.id,
      subscriptionId: sub.id,
    };
  } catch (err) {
    logger.error('[stripe_getIncompletePayment] FAILED', {
      msg: err?.message || String(err),
      stack: err?.stack || null,
    });

    if (err instanceof HttpsError) throw err;
    throw new HttpsError('internal', err?.message || 'Error interno');
  }
});
