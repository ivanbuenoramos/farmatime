// helpers/companyMirror.js
// Espejo en Firestore del estado de suscripción IAP.
const { db, admin } = require('../config/firebase');
const { logger } = require('firebase-functions');

const CANCELED_STATUSES = new Set(['canceled', 'expired', 'revoked', 'on_hold', 'paused']);

function tsFromMillis(ms) {
  if (!ms || typeof ms !== 'number') return null;
  return admin.firestore.Timestamp.fromMillis(ms);
}

// payload esperado:
// {
//   platform: 'ios' | 'android',
//   productId: string,
//   status: 'active' | 'expired' | 'in_grace_period' | 'on_hold' | 'paused' | 'revoked' | 'none',
//   totalSeats: number,
//   originalTransactionId?: string,   // iOS
//   purchaseToken?: string,            // Android
//   expiresAtMs?: number,
//   currentPeriodStartMs?: number,
//   autoRenewing?: boolean,
//   environment?: 'sandbox' | 'production',
// }
// options.ifPurchaseTokenMatches: guarda anti-carrera para las RTDN de Google.
// En un cambio de plan Android (ChangeSubscriptionParam) Google emite
// notificaciones para el token VIEJO (p.ej. SUBSCRIPTION_EXPIRED). Si cuando
// llega la notificación la empresa ya tiene escrito el token NUEVO
// (verifyPurchase ganó la carrera), la notificación es del ciclo anterior y se
// descarta. La comprobación va DENTRO de la transacción: la relectura es
// atómica respecto a la escritura de verifyPurchase.
// options.ifOriginalTransactionIdMatches: guarda equivalente para las
// notificaciones de Apple (que identifican la suscripción por
// originalTransactionId en vez de por purchaseToken).
async function updateCompanyMirror(companyId, payload, options = {}) {
  if (!companyId) return;

  const companyRef = db.collection('companies').doc(companyId);
  const data = {
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  const sub = {};
  if ('platform' in payload) sub.platform = payload.platform ?? null;
  if ('productId' in payload) sub.productId = payload.productId ?? null;
  if ('status' in payload) sub.status = payload.status ?? 'none';
  if ('originalTransactionId' in payload) sub.originalTransactionId = payload.originalTransactionId ?? null;
  if ('purchaseToken' in payload) sub.purchaseToken = payload.purchaseToken ?? null;
  if ('expiresAtMs' in payload) sub.expiresAt = tsFromMillis(payload.expiresAtMs);
  if ('currentPeriodStartMs' in payload) sub.currentPeriodStart = tsFromMillis(payload.currentPeriodStartMs);
  if ('autoRenewing' in payload) sub.autoRenewing = !!payload.autoRenewing;
  if ('environment' in payload) sub.environment = payload.environment ?? null;

  // Mantenemos estos campos top-level para compatibilidad con el resto del código
  // (billingEmployees.js lee billingStatus y contractedSeats).
  if ('status' in payload) {
    data.billingStatus = payload.status ?? 'none';
  }
  if ('totalSeats' in payload && typeof payload.totalSeats === 'number') {
    data.contractedSeats = payload.totalSeats;
  }
  if ('expiresAtMs' in payload) {
    data.currentPeriodEnd = tsFromMillis(payload.expiresAtMs);
  }
  if ('currentPeriodStartMs' in payload) {
    data.currentPeriodStart = tsFromMillis(payload.currentPeriodStartMs);
  }

  // Gating de morosidad: la lectura de `subscription.canceledAt` y su escritura
  // van DENTRO de una transacción para evitar que dos webhooks concurrentes
  // (Apple+Google, doble notif Apple, etc.) lean prev=null a la vez y ambos
  // reseteen canceledAt (lo que falsearía el contador del periodo de gracia).
  await db.runTransaction(async (txn) => {
    let existing = null;
    const expectedToken = options.ifPurchaseTokenMatches;
    const expectedOtid = options.ifOriginalTransactionIdMatches;
    if (expectedToken || expectedOtid) {
      existing = await txn.get(companyRef);
      const currentSub = existing.data()?.subscription || {};
      if (expectedToken && currentSub.purchaseToken &&
          currentSub.purchaseToken !== expectedToken) {
        logger.info('[companyMirror] mirror ignorado: purchaseToken obsoleto', {
          companyId,
        });
        return;
      }
      if (expectedOtid && currentSub.originalTransactionId &&
          currentSub.originalTransactionId !== expectedOtid) {
        logger.info(
            '[companyMirror] mirror ignorado: originalTransactionId obsoleto',
            { companyId },
        );
        return;
      }
    }
    if ('status' in payload) {
      const newStatus = payload.status ?? 'none';
      if (newStatus === 'active' || newStatus === 'trialing') {
        // Reactivación definitiva (pagando y renovando): limpiamos el contador
        // de gracia in-app.
        sub.canceledAt = null;
      } else if (CANCELED_STATUSES.has(newStatus) || newStatus === 'none') {
        // Solo fijamos canceledAt si NO existía ya, para no resetear el contador
        // de gracia con notificaciones repetidas/concurrentes.
        existing = existing || await txn.get(companyRef);
        const prev = existing.data()?.subscription?.canceledAt || null;
        if (!prev) {
          sub.canceledAt = admin.firestore.FieldValue.serverTimestamp();
        } else {
          // Conservamos el timestamp original (no lo sobreescribimos).
          delete sub.canceledAt;
        }
      }
      // in_grace_period / in_billing_retry: estado de pago en curso, ni
      // reactivación ni cancelación → NO tocamos canceledAt.
    }
    if (Object.keys(sub).length > 0) {
      data.subscription = sub;
    }
    txn.set(companyRef, data, { merge: true });
  });
}

// Marca una empresa como cancelada/expirada/revocada conservando
// la información de suscripción previa (productId, originalTransactionId,
// purchaseToken) para que el cliente pueda mostrar la pantalla de renovación
// con contexto y para que el cron de morosidad pueda calcular antigüedad.
//
// NO borra datos del usuario. Solo:
//   - actualiza status / billingStatus
//   - registra canceledAt (si no existía)
//   - fuerza autoRenewing = false
//   - baja contractedSeats a 1 (plaza gratuita)
// options.ifPurchaseTokenMatches / ifOriginalTransactionIdMatches: ver
// comentario en updateCompanyMirror. Evitan que la notificación del
// identificador viejo de un cambio de plan marque como cancelada a una empresa
// que acaba de pagar el plan nuevo.
async function markCompanyAsCanceled(companyId, status, options = {}) {
  if (!companyId) return;
  const finalStatus = CANCELED_STATUSES.has(status) ? status : 'canceled';

  const companyRef = db.collection('companies').doc(companyId);

  // Lectura + escritura en transacción para que dos webhooks concurrentes no
  // reseteen `canceledAt` el uno al otro (ver comentario en updateCompanyMirror).
  // Importante: NO tocamos contractedSeats aquí. Durante el periodo de gracia
  // in-app (30 días tras canceledAt) los empleados deben seguir operativos.
  await db.runTransaction(async (txn) => {
    const snap = await txn.get(companyRef);
    const currentSub = snap.data()?.subscription || {};
    const expectedToken = options.ifPurchaseTokenMatches;
    if (expectedToken && currentSub.purchaseToken &&
        currentSub.purchaseToken !== expectedToken) {
      logger.info(
          '[companyMirror] cancelación ignorada: purchaseToken obsoleto',
          { companyId, status: finalStatus },
      );
      return;
    }
    const expectedOtid = options.ifOriginalTransactionIdMatches;
    if (expectedOtid && currentSub.originalTransactionId &&
        currentSub.originalTransactionId !== expectedOtid) {
      logger.info(
          '[companyMirror] cancelación ignorada: originalTransactionId obsoleto',
          { companyId, status: finalStatus },
      );
      return;
    }
    const prevCanceledAt = snap.data()?.subscription?.canceledAt || null;

    const sub = {
      status: finalStatus,
      autoRenewing: false,
    };
    if (!prevCanceledAt) {
      sub.canceledAt = admin.firestore.FieldValue.serverTimestamp();
    }

    txn.set(
        companyRef,
        {
          subscription: sub,
          billingStatus: finalStatus,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
    );
  });
}

async function resetCompanyToFree(companyId) {
  if (!companyId) return;
  await db.collection('companies').doc(companyId).set(
      {
        subscription: {
          platform: null,
          productId: null,
          status: 'none',
          originalTransactionId: null,
          purchaseToken: null,
          expiresAt: null,
          autoRenewing: false,
          canceledAt: null,
        },
        billingStatus: 'none',
        contractedSeats: 1,
        currentPeriodStart: null,
        currentPeriodEnd: null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
  );
}

async function getCompanyIdFromOriginalTransactionId(originalTransactionId) {
  if (!originalTransactionId) return '';
  const q = await db
      .collection('companies')
      .where('subscription.originalTransactionId', '==', String(originalTransactionId))
      .limit(2)
      .get();
  if (q.empty) return '';
  if (q.size > 1) {
    logger.warn('[companyMirror] originalTransactionId duplicado entre empresas', {
      originalTransactionId,
      ids: q.docs.map((d) => d.id),
    });
  }
  return q.docs[0].id;
}

async function getCompanyIdFromPurchaseToken(purchaseToken) {
  if (!purchaseToken) return '';
  const q = await db
      .collection('companies')
      .where('subscription.purchaseToken', '==', String(purchaseToken))
      .limit(2)
      .get();
  if (q.empty) return '';
  if (q.size > 1) {
    logger.warn('[companyMirror] purchaseToken duplicado entre empresas', {
      purchaseToken,
      ids: q.docs.map((d) => d.id),
    });
  }
  return q.docs[0].id;
}

module.exports = {
  updateCompanyMirror,
  markCompanyAsCanceled,
  resetCompanyToFree,
  getCompanyIdFromOriginalTransactionId,
  getCompanyIdFromPurchaseToken,
};
