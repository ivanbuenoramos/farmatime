const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { db } = require('../config/firebase');
const { getStripe } = require('../config/stripe');
const { assertCompanyAccount } = require('../helpers/assertions');
const logger = require('firebase-functions/logger');

exports.stripe_listInvoices = onCall(async (request) => {
  try {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Login requerido');

    const uid = String(request.auth.uid || '').trim();
    const data = request.data || {};
    const companyId = String(data.companyId || '').trim();
    const limit = Number(data.limit || 50);

    logger.info('[listInvoices] incoming', { uid, companyId, limit });

    if (!companyId) throw new HttpsError('invalid-argument', 'companyId requerido');
    await assertCompanyAccount(uid, companyId);

    const snap = await db.collection('companies').doc(companyId).get();
    logger.info('[listInvoices] company exists?', { exists: snap.exists, docId: companyId });
    if (!snap.exists) throw new HttpsError('not-found', 'Empresa no existe');
    const c = snap.data() || {};
    const customerId = String(c.stripeCustomerId || '').trim();
    if (!customerId) throw new HttpsError('failed-precondition', 'No hay cliente Stripe asignado');

    const stripe = getStripe();
    const invoices = await stripe.invoices.list({
      customer: customerId,
      status: 'paid',
      limit: Math.min(Math.max(limit, 1), 100),
      expand: ['data.charge'],
    });

    const payload = invoices.data
        .filter((inv) => (inv.amount_paid ?? 0) > 0)
        .map((inv) => ({
          id: inv.id,
          number: inv.number || inv.id,
          amountCents: inv.amount_paid ?? inv.amount_due ?? 0,
          created: inv.created,
          pdfUrl: inv.invoice_pdf || null,
          status: inv.status,
          currency: inv.currency,
        }));

    return { ok: true, items: payload };
  } catch (err) {
    const msg = err?.message || 'Stripe invoices error';
    logger.error('[stripe_listInvoices] FAILED', { msg, code: err?.code, stack: err?.stack });
    if (err instanceof HttpsError) throw err;
    throw new HttpsError('internal', msg);
  }
});
