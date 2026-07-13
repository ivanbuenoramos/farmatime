const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { admin } = require('../config/firebase');
const logger = require('firebase-functions/logger');

// Formato de email (mismo criterio razonable que el cliente)
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/**
 * Comprueba si un email se puede usar para crear un empleado:
 *  - que el formato sea correcto
 *  - que no exista ya un usuario en Firebase Auth con ese email
 *
 * Devuelve { available, reason } donde reason ∈
 *  'ok' | 'invalid-format' | 'already-in-use'
 */
exports.checkEmployeeEmailAvailability = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Login requerido');

  const rawEmail = (request.data && request.data.email) || '';
  const email = String(rawEmail).trim().toLowerCase();

  if (!email || !EMAIL_REGEX.test(email)) {
    return { available: false, reason: 'invalid-format' };
  }

  try {
    await admin.auth().getUserByEmail(email);
    // Si no lanza, es que existe un usuario con ese email
    return { available: false, reason: 'already-in-use' };
  } catch (err) {
    const code = err && (err.code || err.errorInfo?.code);

    if (code === 'auth/user-not-found') {
      return { available: true, reason: 'ok' };
    }
    if (code === 'auth/invalid-email') {
      return { available: false, reason: 'invalid-format' };
    }

    logger.error('[checkEmployeeEmailAvailability] ERROR', {
      code,
      msg: err && (err.message || err.errorInfo?.message),
    });
    throw new HttpsError('internal', 'No se pudo comprobar el correo');
  }
});
