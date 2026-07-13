// iap/cleanupLegacyBilling.js
// Limpieza one-shot de campos legacy de Stripe en companies/*.
// App pre-producción: sin usuarios, sin migración de datos — sólo eliminamos
// campos obsoletos e inicializamos la estructura subscription IAP.
//
// Uso:
//   firebase functions:call iap_cleanupLegacyBilling --data '{"dryRun":true}'
// Requiere que el usuario esté autenticado como super-admin (claim adminRole).

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { db, admin } = require('../config/firebase');

const LEGACY_FIELDS = [
  'stripeCustomerId',
  'stripeSubscriptionId',
  'purchasedEmployeeSlots',
  'pendingSeats',
  'scheduledSeats',
  'scheduledPaidSeats',
  'scheduledForPeriodEnd',
];

const DEFAULT_SUBSCRIPTION = {
  platform: null,
  productId: null,
  status: 'none',
  originalTransactionId: null,
  purchaseToken: null,
  expiresAt: null,
  currentPeriodStart: null,
  autoRenewing: false,
  environment: null,
};

exports.iap_cleanupLegacyBilling = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Requiere autenticación.');
  }
  const isAdmin = request.auth.token?.adminRole === true;
  if (!isAdmin) {
    throw new HttpsError('permission-denied', 'Requiere rol de admin.');
  }

  const dryRun = request.data?.dryRun === true;
  const snap = await db.collection('companies').get();

  const updated = [];
  for (const doc of snap.docs) {
    const data = doc.data() || {};
    const patch = {};
    let touched = false;

    for (const field of LEGACY_FIELDS) {
      if (field in data) {
        patch[field] = admin.firestore.FieldValue.delete();
        touched = true;
      }
    }

    if (!data.subscription || typeof data.subscription !== 'object') {
      patch.subscription = { ...DEFAULT_SUBSCRIPTION };
      touched = true;
    }

    if (typeof data.contractedSeats !== 'number' || data.contractedSeats < 1) {
      patch.contractedSeats = 1;
      touched = true;
    }

    if (!data.billingStatus) {
      patch.billingStatus = 'none';
      touched = true;
    }

    if (touched) {
      if (!dryRun) {
        patch.updatedAt = admin.firestore.FieldValue.serverTimestamp();
        await doc.ref.set(patch, { merge: true });
      }
      updated.push(doc.id);
    }
  }

  return {
    dryRun,
    scanned: snap.size,
    updatedCount: updated.length,
    updatedIds: updated,
  };
});
