/* functions/index.js */

const admin = require('firebase-admin');
const {
  onCall,
  onRequest,
  HttpsError,
} = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');
const logger = require('firebase-functions/logger');

// --- Inicializa Firebase ---
admin.initializeApp();
const db = admin.firestore();

// --- Config global ---
setGlobalOptions({
  region: 'europe-west1',
  secrets: ['STRIPE_SECRET', 'PRICE_ID', 'STRIPE_WEBHOOK_SECRET'],
});

// Carga .env.local solo en emulador
if (process.env.FUNCTIONS_EMULATOR) {
  require('dotenv').config({ path: '.env.local' });
}

const PRICE_ID = process.env.PRICE_ID || '';
const WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET || '';

if (!PRICE_ID) logger.warn('⚠️ Falta PRICE_ID en .env/secret');
if (!WEBHOOK_SECRET) logger.warn('⚠️ Falta STRIPE_WEBHOOK_SECRET en .env/secret');

// --- Stripe (inicialización bajo demanda) ---
let _stripe = null;
function getStripe() {
  if (_stripe) return _stripe;
  const Stripe = require('stripe');
  const key = process.env.STRIPE_SECRET || '';
  if (!key) {
    throw new HttpsError('failed-precondition', 'STRIPE_SECRET no configurado');
  }
  _stripe = new Stripe(key, { apiVersion: '2024-06-20' });
  return _stripe;
}

/* =========================
   HELPERS
========================= */

function assertAuth(req) {
  if (!req.auth) {
    throw new HttpsError('unauthenticated', 'Login requerido');
  }
}

// Solo las CUENTAS DE EMPRESA (uid === companyId) pueden gestionar facturación
async function assertCompanyAccount(uid, companyId) {
  const uidStr = String(uid || '').trim();
  const cidStr = String(companyId || '').trim();

  logger.info('[assertCompanyAccount] incoming', { uid: uidStr, companyId: cidStr });

  if (!uidStr || !cidStr) {
    throw new HttpsError('invalid-argument', 'uid/companyId vacío');
  }

  // Si además quieres validar que el doc existe y loguear su contenido:
  const snap = await db.collection('companies').doc(cidStr).get();
  if (!snap.exists) {
    logger.error('[assertCompanyAccount] company not found', { companyId: cidStr });
    throw new HttpsError('not-found', 'Empresa no existe');
  }
  const data = snap.data() || {};
  logger.info('[assertCompanyAccount] company doc', {
    docId: snap.id,
    dataIdField: data.id || null,
    stripeCustomerId: data.stripeCustomerId || null,
    stripeSubscriptionId: data.stripeSubscriptionId || null,
  });

  // Regla: solo cuenta de empresa (uid === companyId)
  const ok = uidStr === cidStr;
  if (!ok) {
    logger.error('[assertCompanyAccount] mismatch', { uid: uidStr, companyId: cidStr });
    throw new HttpsError('permission-denied', 'Solo la cuenta de empresa puede gestionar la facturación');
  }

  logger.info('[assertCompanyAccount] OK');
}

async function updateCompanyMirror(companyId, payload) {
  const data = { updatedAt: admin.firestore.FieldValue.serverTimestamp() };
  if (payload.stripeCustomerId) data.stripeCustomerId = payload.stripeCustomerId;
  if (payload.stripeSubscriptionId) data.stripeSubscriptionId = payload.stripeSubscriptionId;
  if (typeof payload.contractedSeats === 'number') data.contractedSeats = payload.contractedSeats;
  if (payload.billingStatus) data.billingStatus = payload.billingStatus;
  if (payload.currentPeriodEnd) {
    data.currentPeriodEnd = admin.firestore.Timestamp.fromMillis(payload.currentPeriodEnd * 1000);
  }
  await db.collection('companies').doc(companyId).set(data, { merge: true });
}

async function getCompanyIdFromCustomer(customerId) {
  const q = await db
      .collection('companies')
      .where('stripeCustomerId', '==', customerId)
      .limit(1)
      .get();

  if (!q.empty) return q.docs[0].id;

  const stripe = getStripe();
  const customer = await stripe.customers.retrieve(customerId);
  return (customer && customer.metadata && customer.metadata.companyId) || '';
}

/* =========================
   FUNCTIONS
========================= */

// 1️⃣ Crear Customer + Subscription
exports.stripe_createCustomerAndSubscription = onCall(async (request) => {
  assertAuth(request);
  const uid = request.auth.uid;
  const data = request.data || {};

  const companyId = String(data.companyId || '');
  const initialQuantity = Number(data.initialQuantity || 1);

  if (!companyId) throw new HttpsError('invalid-argument', 'companyId requerido');
  if (!Number.isInteger(initialQuantity) || initialQuantity <= 0) {
    throw new HttpsError('invalid-argument', 'initialQuantity inválido');
  }
  if (!PRICE_ID) throw new HttpsError('failed-precondition', 'PRICE_ID no configurado');

  assertCompanyAccount(uid, companyId);

  const companyRef = db.collection('companies').doc(companyId);
  const companySnap = await companyRef.get();
  if (!companySnap.exists) throw new HttpsError('not-found', 'Empresa no existe');
  const c = companySnap.data() || {};

  // Evita duplicados
  if (c.stripeCustomerId && c.stripeSubscriptionId) {
    return {
      ok: true,
      reused: true,
      stripeCustomerId: c.stripeCustomerId,
      stripeSubscriptionId: c.stripeSubscriptionId,
    };
  }

  const stripe = getStripe();

  // Crear Customer
  const customer = await stripe.customers.create({
    email: c.email || undefined,
    metadata: { companyId },
  });

  // Crear Subscription
  const subscription = await stripe.subscriptions.create({
    customer: customer.id,
    items: [{ price: PRICE_ID, quantity: initialQuantity }],
    collection_method: 'charge_automatically',
    expand: ['latest_invoice.payment_intent'],
  });

  const item = subscription.items.data[0];
  const qty = (item && typeof item.quantity === 'number') ? item.quantity : initialQuantity;

  await updateCompanyMirror(companyId, {
    stripeCustomerId: customer.id,
    stripeSubscriptionId: subscription.id,
    contractedSeats: qty,
    billingStatus: subscription.status,
    currentPeriodEnd: subscription.current_period_end,
  });

  return { ok: true, subscriptionId: subscription.id };
});

// 2️⃣ Actualizar número de empleados contratados
exports.stripe_updateSubscriptionQuantity = onCall(async (request) => {
  assertAuth(request);
  const uid = request.auth.uid;
  const data = request.data || {};

  const companyId = String(data.companyId || '');
  const quantity = Number(data.quantity || 1);
  const prorationBehaviorRaw = String(data.proration_behavior || '');
  const prorationBehavior =
    prorationBehaviorRaw === 'none' ? 'none' : 'create_prorations';

  if (!companyId) throw new HttpsError('invalid-argument', 'companyId requerido');
  if (!Number.isInteger(quantity) || quantity <= 0) {
    throw new HttpsError('invalid-argument', 'quantity inválido');
  }

  assertCompanyAccount(uid, companyId);

  const snap = await db.collection('companies').doc(companyId).get();
  const company = snap.data() || {};
  if (!company.stripeSubscriptionId) {
    throw new HttpsError('failed-precondition', 'No hay suscripción Stripe');
  }

  const stripe = getStripe();
  const subscription = await stripe.subscriptions.retrieve(company.stripeSubscriptionId);
  const itemId = subscription.items.data[0].id;

  const updatedItem = await stripe.subscriptionItems.update(itemId, {
    quantity,
    proration_behavior: prorationBehavior,
  });

  const subAfter = await stripe.subscriptions.retrieve(subscription.id);

  await updateCompanyMirror(companyId, {
    contractedSeats: updatedItem.quantity ?? quantity,
    billingStatus: subAfter.status,
    currentPeriodEnd: subAfter.current_period_end,
  });

  return { ok: true, quantity: updatedItem.quantity };
});

// 3️⃣ Crear sesión de Billing Portal
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

/* =========================
   WEBHOOK
========================= */
exports.stripe_webhook = onRequest(async (req, res) => {
  const sig = req.headers['stripe-signature'];
  if (!WEBHOOK_SECRET) {
    logger.error('⚠️ Falta STRIPE_WEBHOOK_SECRET en .env/secret');
    return res.status(500).send('Webhook secret no configurado');
  }

  let event;
  try {
    const stripe = getStripe();
    event = stripe.webhooks.constructEvent(req.rawBody, sig, WEBHOOK_SECRET);
  } catch (err) {
    logger.error('❌ Verificación de firma fallida:', err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  try {
    switch (event.type) {
      case 'customer.subscription.created':
      case 'customer.subscription.updated': {
        const sub = event.data.object;
        const companyId =
          (sub.metadata && sub.metadata.companyId) ||
          (await getCompanyIdFromCustomer(sub.customer));

        const first = sub.items?.data?.[0];
        const quantity = first?.quantity || 0;

        await updateCompanyMirror(companyId, {
          contractedSeats: quantity,
          billingStatus: sub.status,
          currentPeriodEnd: sub.current_period_end,
        });
        break;
      }
      case 'customer.subscription.deleted': {
        const sub = event.data.object;
        const companyId =
          (sub.metadata && sub.metadata.companyId) ||
          (await getCompanyIdFromCustomer(sub.customer));
        await updateCompanyMirror(companyId, { billingStatus: 'canceled' });
        break;
      }
      case 'invoice.paid': {
        const inv = event.data.object;
        const companyId = await getCompanyIdFromCustomer(inv.customer);
        await db
            .collection('companies')
            .doc(companyId)
            .collection('invoices')
            .doc(inv.id)
            .set({
              number: inv.number || inv.id,
              amountCents: inv.amount_paid || 0,
              date: admin.firestore.Timestamp.fromMillis((inv.created || 0) * 1000),
              pdfUrl: inv.invoice_pdf || null,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        break;
      }
      case 'invoice.payment_failed': {
        const inv = event.data.object;
        const companyId = await getCompanyIdFromCustomer(inv.customer);
        await updateCompanyMirror(companyId, { billingStatus: 'past_due' });
        break;
      }
      default:
        break;
    }
  } catch (e) {
    logger.error('❌ Error manejando webhook:', e);
    return res.status(500).send('Internal error');
  }

  res.json({ received: true });
});

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
      limit: Math.min(Math.max(limit, 1), 100),
      expand: ['data.charge'],
    });

    // Normalizamos lo que necesita la app
    const payload = invoices.data.map((inv) => ({
      id: inv.id,
      number: inv.number || inv.id,
      amountCents: inv.amount_paid ?? inv.amount_due ?? 0, // en centimos
      created: inv.created, // epoch seconds
      pdfUrl: inv.invoice_pdf || null,
      status: inv.status, // paid, open, draft, uncollectible
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
