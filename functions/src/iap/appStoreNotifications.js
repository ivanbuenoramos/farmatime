// appStoreNotifications.js
// App Store Server Notifications v2.
// URL configurada en App Store Connect → App Information → Server Notifications.
const { onRequest } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
const { db, admin } = require('../config/firebase');
const { verifyAppleJws } = require('./helpers/verifyAppleJws');
const { getPlan } = require('./helpers/planCatalog');
const {
  updateCompanyMirror,
  markCompanyAsCanceled,
  getCompanyIdFromOriginalTransactionId,
} = require('../helpers/companyMirror');
const { updateEmployeesForBillingState } = require('../helpers/billingEmployees');

function mapNotificationToStatus(notificationType, subtype) {
  // Ref: https://developer.apple.com/documentation/appstoreservernotifications/notificationtype
  switch (notificationType) {
    case 'SUBSCRIBED':
    case 'DID_RENEW':
    case 'OFFER_REDEEMED':
      return 'active';

    case 'DID_CHANGE_RENEWAL_STATUS':
      return 'active'; // el status real lo deducimos de autoRenewing; plaza sigue activa

    case 'DID_CHANGE_RENEWAL_PREF':
      return 'active'; // cambio de plan programado; sigue activa hasta caducar

    case 'GRACE_PERIOD_EXPIRED':
      return 'expired';

    case 'DID_FAIL_TO_RENEW':
      return subtype === 'GRACE_PERIOD' ? 'in_grace_period' : 'expired';

    case 'EXPIRED':
      return 'expired';

    case 'REVOKE':
    case 'REFUND':
      return 'revoked';

    case 'PRICE_INCREASE':
      return 'active';

    default:
      return null;
  }
}

// Reclama el procesamiento de un evento de forma atómica. Devuelve true si lo
// reclamamos (primera vez) y false si ya estaba reclamado/procesado (duplicado).
async function claimEvent(eventId) {
  if (!eventId) return true; // sin id no podemos deduplicar; procesamos igual
  const ref = db.collection('_appleEvents').doc(eventId);
  return db.runTransaction(async (txn) => {
    const doc = await txn.get(ref);
    if (doc.exists) return false;
    txn.set(ref, { createdAt: admin.firestore.FieldValue.serverTimestamp() });
    return true;
  });
}

// Libera el claim para que Apple pueda reintentar (p.ej. cuando aún no podemos
// resolver la empresa en la 1ª compra: el vínculo originalTransactionId→empresa
// lo escribe el verify del cliente, que puede llegar justo después).
async function releaseEvent(eventId) {
  if (!eventId) return;
  try {
    await db.collection('_appleEvents').doc(eventId).delete();
  } catch (_) {
    // best-effort
  }
}

exports.iap_appStoreNotifications = onRequest(
    { region: 'europe-west1', secrets: [] },
    async (req, res) => {
      // Lo recordamos para poder LIBERAR el claim si no logramos procesar la
      // notificación (y que Apple la reintente más tarde).
      let claimedEventId = null;
      try {
        const body = req.body || {};
        const signedPayload = body.signedPayload;
        if (!signedPayload) {
          logger.warn('[appleNotif] sin signedPayload');
          return res.status(400).send('Missing signedPayload');
        }

        // El endpoint es público y sin auth: verificamos la firma del JWS contra
        // la cadena de certificados de Apple antes de confiar en el contenido.
        // Si la firma no es válida → 401 (no procesamos nada).
        let payload;
        try {
          payload = await verifyAppleJws(signedPayload);
        } catch (err) {
          logger.warn('[appleNotif] firma inválida', { msg: err?.message });
          return res.status(401).send('Invalid signature');
        }
        if (!payload) return res.status(400).send('Invalid signedPayload');

        const notificationType = payload.notificationType;
        const subtype = payload.subtype;
        const notificationUUID = payload.notificationUUID;

        logger.info('[appleNotif]', { notificationType, subtype, notificationUUID });

        // Idempotencia: reclamamos el evento. Si ya estaba reclamado → duplicado.
        if (!(await claimEvent(notificationUUID))) {
          return res.json({ received: true, duplicated: true });
        }
        claimedEventId = notificationUUID;

        const data = payload.data || {};
        let tx = null;
        let renewal = null;
        try {
          if (data.signedTransactionInfo) {
            tx = await verifyAppleJws(data.signedTransactionInfo);
          }
          if (data.signedRenewalInfo) {
            renewal = await verifyAppleJws(data.signedRenewalInfo);
          }
        } catch (err) {
          logger.warn('[appleNotif] firma de transacción/renovación inválida', {
            msg: err?.message,
          });
          return res.status(401).send('Invalid signature');
        }

        if (!tx) {
          logger.warn('[appleNotif] sin signedTransactionInfo');
          return res.json({ received: true });
        }

        const originalTransactionId = String(tx.originalTransactionId || tx.transactionId || '');
        const productId = tx.productId;
        const plan = getPlan(productId);

        const companyId = await getCompanyIdFromOriginalTransactionId(originalTransactionId);
        if (!companyId) {
          // 1ª compra: el vínculo originalTransactionId→empresa lo escribe el
          // verify del cliente, que puede llegar justo después de esta notif.
          // Liberamos el claim y devolvemos 503 para que Apple REINTENTE más
          // tarde (reintenta con backoff durante ~3 días), momento en que el
          // vínculo ya existirá. Así no se pierde la notificación.
          logger.warn('[appleNotif] empresa aún no vinculada, reintentar', {
            originalTransactionId,
            notificationType,
          });
          await releaseEvent(claimedEventId);
          claimedEventId = null;
          return res.status(503).send('company not linked yet, retry later');
        }

        const status = mapNotificationToStatus(notificationType, subtype);

        if (status === 'revoked' || status === 'expired') {
          // No reseteamos la suscripción: preservamos contexto y registramos
          // canceledAt para el periodo de gracia in-app (30 días) en el que la
          // farmacia ve la pantalla de renovar pero los empleados siguen
          // operativos.
          // La guarda por originalTransactionId (simétrica a la de Google por
          // purchaseToken) descarta notificaciones de una suscripción vieja si
          // la empresa ya tiene vinculada otra distinta.
          await markCompanyAsCanceled(companyId, status, {
            ifOriginalTransactionIdMatches: originalTransactionId,
          });
          await updateEmployeesForBillingState(companyId);
          return res.json({ received: true, status });
        }

        if (status === 'active' || status === 'in_grace_period') {
          if (!plan) {
            logger.warn('[appleNotif] productId no está en catálogo', { productId });
            return res.json({ received: true });
          }

          await updateCompanyMirror(companyId, {
            platform: 'ios',
            productId,
            status,
            totalSeats: plan.totalSeats,
            originalTransactionId,
            expiresAtMs: Number(tx.expiresDate) || null,
            currentPeriodStartMs: Number(tx.purchaseDate) || null,
            autoRenewing: renewal ? renewal.autoRenewStatus === 1 : true,
            environment: data.environment === 'Production' ? 'production' : 'sandbox',
          }, { ifOriginalTransactionIdMatches: originalTransactionId });
          await updateEmployeesForBillingState(companyId);
        }

        return res.json({ received: true });
      } catch (e) {
        logger.error('[appleNotif] error', { msg: e?.message, stack: e?.stack });
        // Error transitorio: liberamos el claim para que Apple reintente.
        await releaseEvent(claimedEventId);
        return res.status(500).send('Internal error');
      }
    },
);
