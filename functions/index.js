/* functions/index.js */

const admin = require('firebase-admin');
const {
  onCall,
  onRequest,
  HttpsError,
} = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');
const logger = require('firebase-functions/logger');

// const MOBILE_STRIPE_VERSION = '2024-06-20';

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
      case 'customer.subscription.updated': {
        // ✅ solo reflejamos estado y periodo; NO actualizamos contractedSeats aquí
        const sub = event.data.object;
        const companyId =
          (sub.metadata && sub.metadata.companyId) ||
          (await getCompanyIdFromCustomer(sub.customer));

        await updateCompanyMirror(companyId, {
          billingStatus: sub.status,
          currentPeriodEnd: sub.current_period_end,
        });
        break;
      }

      case 'customer.subscription.created': {
        // Puedes reflejar estado/periodo inicial si quieres, pero NO contractedSeats
        const sub = event.data.object;
        const companyId =
          (sub.metadata && sub.metadata.companyId) ||
          (await getCompanyIdFromCustomer(sub.customer));

        await updateCompanyMirror(companyId, {
          billingStatus: sub.status,
          currentPeriodEnd: sub.current_period_end,
        });
        break;
      }

      case 'invoice.paid': {
        const inv = event.data.object;

        // Guarda factura si quieres (aunque amount_paid == 0 no merece la pena)
        const companyId = await getCompanyIdFromCustomer(inv.customer);
        if ((inv.amount_paid ?? 0) > 0) {
          await db.collection('companies').doc(companyId)
              .collection('invoices').doc(inv.id)
              .set({
                number: inv.number || inv.id,
                amountCents: inv.amount_paid || 0,
                date: admin.firestore.Timestamp.fromMillis((inv.created || 0) * 1000),
                pdfUrl: inv.invoice_pdf || null,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              }, { merge: true });
        }

        // ✅ AHORA sincronizamos plazas desde la suscripción real
        const stripe = getStripe();
        const subId = typeof inv.subscription === 'string' ?
          inv.subscription :
          inv.subscription?.id;

        if (subId) {
          const s = await stripe.subscriptions.retrieve(subId, {
            expand: ['items.data'],
          });
          const newQty = s?.items?.data?.[0]?.quantity ?? null;

          await updateCompanyMirror(companyId, {
            // Solo reflejamos plazas tras un pago "paid"
            contractedSeats: (typeof newQty === 'number') ? newQty : undefined,
            billingStatus: s.status,
            currentPeriodEnd: s.current_period_end,
          });
        }

        break;
      }

      case 'invoice.payment_failed': {
        const inv = event.data.object;
        const companyId = await getCompanyIdFromCustomer(inv.customer);
        await updateCompanyMirror(companyId, { billingStatus: 'past_due' });
        break;
      }
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

// 4️⃣ Preparar pago para cambio de plazas (PaymentSheet in-app)
exports.stripe_prepareSeatChangePayment = onCall(async (request) => {
  try {
    assertAuth(request);
    const uid = String(request.auth.uid || '').trim();
    const data = request.data || {};
    const companyId = String(data.companyId || '').trim();
    const newQuantity = Number(data.newQuantity || 0);

    if (!companyId) throw new HttpsError('invalid-argument', 'companyId requerido');
    if (!Number.isInteger(newQuantity) || newQuantity < 1) {
      throw new HttpsError('invalid-argument', 'newQuantity inválido');
    }

    await assertCompanyAccount(uid, companyId);

    // Empresa y sub
    const doc = await db.collection('companies').doc(companyId).get();
    if (!doc.exists) throw new HttpsError('not-found', 'Empresa no existe');
    const company = doc.data() || {};
    const subscriptionId = String(company.stripeSubscriptionId || '').trim();
    if (!subscriptionId) {
      throw new HttpsError('failed-precondition', 'No hay suscripción Stripe asociada');
    }

    const stripe = getStripe();

    // Suscripción actual (con items)
    const sub = await stripe.subscriptions.retrieve(subscriptionId, {
      expand: ['items.data.price'],
    });
    if (!sub?.items?.data?.length) {
      throw new HttpsError('internal', 'No se encontró el item de suscripción');
    }
    const item = sub.items.data[0];

    // ⚠️ IMPORTANTE:
    // Actualizamos la suscripción con payment_behavior=default_incomplete para que Stripe
    // genere una invoice + (si hay importe) un PaymentIntent que exigirá PaymentSheet.
    // NO ESPEJAMOS NADA EN FIRESTORE AQUÍ.
    const updated = await stripe.subscriptions.update(sub.id, {
      payment_behavior: 'default_incomplete',
      proration_behavior: 'always_invoice',
      billing_cycle_anchor: 'now',
      items: [{ id: item.id, quantity: newQuantity }],
      expand: ['latest_invoice.payment_intent', 'customer'],
    });

    const invoice = updated.latest_invoice || null;
    const paymentIntent = invoice?.payment_intent || null;

    // Si NO hay PaymentIntent es porque el total es 0€ (no hay cargo ahora).
    // AÚN ASÍ no tocamos Firestore. El espejo de plazas solo se mueve en invoice.paid.
    if (!paymentIntent) {
      const newQty = updated.items.data[0].quantity;

      // ✅ Espejar en Firestore cuando NO hay cobro (total = 0)
      await updateCompanyMirror(companyId, {
        contractedSeats: newQty,
        billingStatus: updated.status,
        currentPeriodEnd: updated.current_period_end,
      });

      const customerId = updated.customer?.id ? updated.customer.id : updated.customer;
      return {
        ok: true,
        requiresPayment: false,
        customerId,
        ephemeralKeySecret: null,
        paymentIntentClientSecret: null,
        subscriptionId: updated.id,
        newQuantity: newQty,
        amountCents: invoice ? (invoice.total || 0) : 0,
        currency: invoice ? (invoice.currency || 'eur') : 'eur',
      };
    }

    // Hay PaymentIntent -> devolvemos secretos para PaymentSheet
    const customerId = updated.customer?.id ? updated.customer.id : updated.customer;
    const eph = await stripe.ephemeralKeys.create(
        { customer: customerId },
        { apiVersion: '2024-06-20' },
    );

    return {
      ok: true,
      requiresPayment: true,
      customerId,
      ephemeralKeySecret: eph.secret,
      paymentIntentClientSecret: paymentIntent.client_secret,
      subscriptionId: updated.id,
      newQuantity: updated.items.data[0].quantity,
      amountCents: invoice.total || 0,
      currency: invoice.currency || 'eur',
    };
  } catch (err) {
    logger.error('[prepareSeatChangePayment] FAILED', {
      msg: err?.message || String(err),
      stack: err?.stack || null,
    });
    if (err instanceof HttpsError) throw err;
    throw new HttpsError('internal', err?.message || 'Error interno');
  }
});

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

/* =========================
   EMPLEADOS
========================= */
// (Opcional) Asegura que quien llama es la cuenta de empresa (mismo uid = companyId)
async function assertCompanyForEmployeeCreation(uid, companyId) {
  // Si ya tienes `assertCompanyAccount`, puedes usarla aquí para unificar reglas:
  // return assertCompanyAccount(uid, companyId);
  const snap = await db.collection('companies').doc(companyId).get();
  if (!snap.exists) throw new HttpsError('not-found', 'Empresa no encontrada');
  if (String(uid || '') !== String(companyId || '')) {
    throw new HttpsError('permission-denied', 'Solo la cuenta de empresa puede crear empleados');
  }
}

// Crear cuenta de empleado (Auth + Firestore) validando plazas en servidor
exports.createEmployeeAccount = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Login requerido');
  const callerUid = request.auth.uid;

  const {
    companyId,
    name,
    email,
    hourlyRate = 0,
    role = 'tecnico',
    roleOther = null,
    workdayType = null,
    vacationDaysPer30 = 2.5,
    personalDaysPerYear = 0,
  } = request.data || {};

  // Validaciones
  if (!companyId || typeof companyId !== 'string') {
    throw new HttpsError('invalid-argument', 'companyId inválido');
  }
  if (!name || typeof name !== 'string') {
    throw new HttpsError('invalid-argument', 'name inválido');
  }
  if (!email || typeof email !== 'string') {
    throw new HttpsError('invalid-argument', 'email inválido');
  }

  // Autorización
  await assertCompanyForEmployeeCreation(callerUid, companyId);

  // Helpers locales
  async function countActiveEmployees(companyId) {
    const agg = await db
        .collection('employees')
        .where('companyId', '==', companyId)
        .where('isActive', '==', true)
        .count()
        .get();
    return agg.data().count || 0;
  }
  async function getContractedSeats(companyId) {
    const snap = await db.collection('companies').doc(companyId).get();
    if (!snap.exists) throw new HttpsError('not-found', 'Empresa no encontrada');
    const data = snap.data() || {};
    return (typeof data.contractedSeats === 'number' ? data.contractedSeats : data.purchasedEmployeeSlots) || 0;
  }

  logger.info('[createEmployeeAccount] START', { companyId, email, role });

  // Chequeo plazas (pre)
  const maxSeats = await getContractedSeats(companyId);
  const activeBefore = await countActiveEmployees(companyId);
  logger.info('[createEmployeeAccount] seats/pre', { maxSeats, activeBefore });
  if (activeBefore >= maxSeats) {
    throw new HttpsError('failed-precondition', 'Sin plazas disponibles');
  }

  let createdUser = null;
  try {
    // Crear usuario
    const tempPass = Math.random().toString(36).slice(-10) + 'A!';
    createdUser = await admin.auth().createUser({
      email,
      password: tempPass,
      displayName: name,
      emailVerified: false,
      disabled: false,
    });
    logger.info('[createEmployeeAccount] auth user created', { uid: createdUser.uid, email });

    // Custom claims opcionales
    await admin.auth().setCustomUserClaims(createdUser.uid, { companyId, role }).catch((e) => {
      logger.warn('[createEmployeeAccount] setCustomUserClaims warn', { code: e.code, msg: e.message });
    });

    // Rechequeo plazas
    const activeAfter = await countActiveEmployees(companyId);
    logger.info('[createEmployeeAccount] seats/post-auth', { maxSeats, activeAfter });
    if (activeAfter >= maxSeats) {
      try {
        await admin.auth().deleteUser(createdUser.uid);
      } catch (_) {
        // noop
      }
      throw new HttpsError('failed-precondition', 'Sin plazas disponibles');
    }

    // Crear doc empleado
    const employeeDoc = {
      uid: createdUser.uid,
      companyId,
      name,
      email,
      isActive: true,
      hourlyRate: Number(hourlyRate) || 0,
      role,
      roleOther: roleOther || null,
      workdayType: workdayType || null,
      vacationDaysPer30: Number(vacationDaysPer30) || 2.5,
      personalDaysPerYear: Number(personalDaysPerYear) || 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.collection('employees').doc(createdUser.uid).set(employeeDoc);
    logger.info('[createEmployeeAccount] employee doc created', { uid: createdUser.uid });

    // Reset link (no crítico)
    let resetLink = null;
    try {
      // ⚠️ Asegúrate de que la URL esté en Auth > Dominios autorizados.
      // Si no, quita el objeto de settings y deja el valor por defecto:
      // resetLink = await admin.auth().generatePasswordResetLink(email);
      resetLink = await admin.auth().generatePasswordResetLink(email, {
        url: 'https://tudominio.com/onboarding', // <- autoriza este dominio o usa tu *.web.app / *.firebaseapp.com
        handleCodeInApp: true,
      });
      logger.info('[createEmployeeAccount] resetLink generated');
    } catch (e) {
      logger.warn('[createEmployeeAccount] resetLink warn', { code: e.code, msg: e.message });
      // No fallamos la función por esto
    }

    logger.info('[createEmployeeAccount] DONE', { uid: createdUser.uid });
    return { uid: createdUser.uid, resetLink };
  } catch (err) {
    // Mapeo de errores comunes para evitar "INTERNAL" genérico
    const code = err && (err.code || err.errorInfo?.code);
    const msg = err && (err.message || err.errorInfo?.message);

    logger.error('[createEmployeeAccount] ERROR', { code, msg, stack: err?.stack });

    // Limpieza si se creó el usuario
    if (createdUser?.uid) {
      try {
        await admin.auth().deleteUser(createdUser.uid);
      } catch (_) {
        // noop
      }
    }

    // Mapear errores típicos de Auth Admin
    if (code === 'auth/email-already-exists') {
      throw new HttpsError('already-exists', 'El correo ya está en uso');
    }
    if (code === 'auth/invalid-email') {
      throw new HttpsError('invalid-argument', 'Email inválido');
    }
    if (code === 'auth/operation-not-allowed') {
      throw new HttpsError('failed-precondition', 'Operación no permitida');
    }
    if (code === 'auth/uid-already-exists') {
      throw new HttpsError('already-exists', 'UID ya existe');
    }
    if (code === 'auth/invalid-password') {
      throw new HttpsError('invalid-argument', 'Password inválida');
    }
    if (code === 'failed-precondition') {
      // por si lanzamos nosotros mismos antes
      throw new HttpsError('failed-precondition', msg || 'Fallo de precondición');
    }

    throw new HttpsError('internal', msg || 'Error interno');
  }
});
