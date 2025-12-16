const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { db } = require('../config/firebase');
const { assertAuth, assertCompanyAccount } = require('../helpers/assertions');
const { updateCompanyMirror } = require('../helpers/companyMirror');
const { getStripe } = require('../config/stripe');

exports.stripe_createCustomerAndSubscription = onCall(async (request) => {
  assertAuth(request);
  const uid = request.auth.uid;
  const data = request.data || {};
  const companyId = String(data.companyId || '').trim();

  if (!companyId) throw new HttpsError('invalid-argument', 'companyId requerido');

  await assertCompanyAccount(uid, companyId);

  const companyRef = db.collection('companies').doc(companyId);
  const snap = await companyRef.get();
  if (!snap.exists) throw new HttpsError('not-found', 'Empresa no existe');
  const c = snap.data() || {};

  // Si ya hay customer, no lo vuelvas a crear
  if (c.stripeCustomerId) {
    // Asegura defaults coherentes (por si venías del flujo viejo)
    await updateCompanyMirror(companyId, {
      stripeCustomerId: c.stripeCustomerId,
      // Suscripción aún no creada en el nuevo flujo
      stripeSubscriptionId: c.stripeSubscriptionId || null,
      // En "sin suscripción" el mínimo es 1 asiento (gratis)
      contractedSeats: typeof c.contractedSeats === 'number' && c.contractedSeats > 0 ? c.contractedSeats : 1,
      billingStatus: c.billingStatus || 'none',
      currentPeriodEnd: c.currentPeriodEnd || null,
    });

    return { ok: true, customerId: c.stripeCustomerId, alreadyExisted: true };
  }

  const stripe = getStripe();

  const customer = await stripe.customers.create({
    email: c.email || undefined,
    name: c.name || undefined,
    metadata: { companyId },
  });

  // Nuevo estado: customer creado, pero sin suscripción todavía
  await updateCompanyMirror(companyId, {
    stripeCustomerId: customer.id,
    stripeSubscriptionId: null,
    contractedSeats: 1,
    billingStatus: 'none',
    currentPeriodEnd: null,
  });

  return { ok: true, customerId: customer.id, alreadyExisted: false };
});
