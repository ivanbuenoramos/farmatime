// functions/src/notifications/sendPush.js
//
// Helper reutilizable para enviar notificaciones push (FCM) a uno o varios
// usuarios de Farmatime. Cada trigger de negocio (chat, ausencias, turnos,
// fichajes, billing) debe llamar a `sendPushToUsers` con los uids destino.
//
// Contrato del payload `data` (debe ir sincronizado con el cliente Flutter,
// PushNotificationService._routeFromData):
//   - type: 'chat_message' | 'leave_request' | 'leave_status' |
//           'schedule_change' | 'clock_alert' | 'billing'
//   - + ids necesarios para el deep-link (p.ej. conversationId)
//
// Tokens en Firestore: user_fcm_tokens/{uid}/tokens/{token}
// Preferencias del usuario: user_fcm_tokens/{uid}.prefs (las escribe la app,
// pantalla de Notificaciones). Sin doc o sin campo = todo activado.

const { logger } = require('firebase-functions');
const { admin, db } = require('../config/firebase');

// Toggle de preferencias que gobierna cada `data.type`. Los tipos operativos
// (clock_alert, billing, employee_active/deleted, report_ready) no tienen
// toggle: se envían siempre (solo los apaga pushEnabled=false).
const PREF_BY_TYPE = {
  chat_message: 'chatMessages',
  leave_request: 'leaveRequests',
  leave_status: 'leaveStatusUpdates',
  schedule_change: 'scheduleChanges',
};

/**
 * Quita de la lista los uids que han desactivado este tipo de push en sus
 * preferencias. Ante cualquier error de lectura se envía a todos (mejor una
 * notificación de más que perder una importante).
 * @param {string[]} uids
 * @param {string|undefined} type   valor de data.type del payload
 * @return {Promise<string[]>}
 */
async function filterUidsByPrefs(uids, type) {
  if (!uids.length) return uids;
  let snaps;
  try {
    const refs = uids.map((uid) => db.collection('user_fcm_tokens').doc(uid));
    snaps = await db.getAll(...refs);
  } catch (e) {
    logger.warn('sendPushToUsers: error leyendo prefs; se envía a todos', e);
    return uids;
  }
  const prefKey = PREF_BY_TYPE[type];
  return uids.filter((uid, i) => {
    const prefs = snaps[i].get('prefs') || {};
    if (prefs.pushEnabled === false) return false;
    if (prefKey && prefs[prefKey] === false) return false;
    return true;
  });
}

/**
 * Lee todos los tokens FCM registrados para un uid.
 * @param {string} uid
 * @return {Promise<string[]>}
 */
async function getTokensForUser(uid) {
  if (!uid) return [];
  const snap = await db
      .collection('user_fcm_tokens')
      .doc(uid)
      .collection('tokens')
      .get();
  return snap.docs
      .map((d) => d.get('token') || d.id)
      .filter((t) => typeof t === 'string' && t.length > 0);
}

/**
 * Borra de Firestore los tokens que FCM ha marcado como inválidos
 * (desinstalación, token caducado, etc.).
 * @param {string[]} uids   uids a los que pertenecen los tokens
 * @param {string[]} invalidTokens
 */
async function pruneInvalidTokens(uids, invalidTokens) {
  if (!invalidTokens.length) return;
  const invalid = new Set(invalidTokens);
  const batch = db.batch();
  for (const uid of uids) {
    for (const token of invalid) {
      batch.delete(
          db
              .collection('user_fcm_tokens')
              .doc(uid)
              .collection('tokens')
              .doc(token),
      );
    }
  }
  try {
    await batch.commit();
  } catch (e) {
    logger.warn('No se pudieron limpiar tokens inválidos', e);
  }
}

/**
 * Envía una notificación push a una lista de usuarios.
 *
 * @param {Object} params
 * @param {string[]} params.uids        destinatarios (se ignoran los vacíos / duplicados)
 * @param {string} params.title         título visible
 * @param {string} params.body          cuerpo visible
 * @param {Object} [params.data]        payload de datos (todos los valores se serializan a string)
 * @return {Promise<{successCount:number, failureCount:number}>}
 */
async function sendPushToUsers({ uids, title, body, data = {} }) {
  const uniqueUids = [...new Set((uids || []).filter(Boolean))];
  if (!uniqueUids.length) {
    logger.info('sendPushToUsers: sin destinatarios');
    return { successCount: 0, failureCount: 0 };
  }

  // Respeta las preferencias de notificaciones de cada destinatario.
  const allowedUids = await filterUidsByPrefs(uniqueUids, data.type);
  if (!allowedUids.length) {
    logger.info(
        'sendPushToUsers: todos los destinatarios tienen este tipo desactivado',
        { type: data.type || null },
    );
    return { successCount: 0, failureCount: 0 };
  }

  // Recoge tokens de todos los usuarios y recuerda a qué uid pertenece cada uno.
  const tokenLists = await Promise.all(allowedUids.map(getTokensForUser));
  const tokens = [];
  for (const list of tokenLists) {
    for (const t of list) tokens.push(t);
  }
  const allTokens = [...new Set(tokens)];

  if (!allTokens.length) {
    logger.info('sendPushToUsers: los destinatarios no tienen tokens FCM');
    return { successCount: 0, failureCount: 0 };
  }

  // FCM exige que todos los valores de `data` sean strings.
  const stringData = {};
  for (const [k, v] of Object.entries(data)) {
    stringData[k] = v == null ? '' : String(v);
  }

  const message = {
    tokens: allTokens,
    notification: { title, body },
    data: stringData,
    android: {
      priority: 'high',
      notification: { channelId: 'farmatime_default' },
    },
    apns: {
      payload: { aps: { sound: 'default', badge: 1 } },
    },
  };

  const resp = await admin.messaging().sendEachForMulticast(message);

  // Detecta tokens inválidos para limpiarlos.
  const invalidTokens = [];
  resp.responses.forEach((r, i) => {
    if (r.success) return;
    const code = r.error && r.error.code;
    if (
      code === 'messaging/invalid-registration-token' ||
      code === 'messaging/registration-token-not-registered'
    ) {
      invalidTokens.push(allTokens[i]);
    }
  });
  await pruneInvalidTokens(allowedUids, invalidTokens);

  logger.info(
      `sendPushToUsers: ${resp.successCount} ok / ${resp.failureCount} fallos ` +
      `(${invalidTokens.length} tokens inválidos limpiados)`,
  );
  return { successCount: resp.successCount, failureCount: resp.failureCount };
}

module.exports = { sendPushToUsers, getTokensForUser };
