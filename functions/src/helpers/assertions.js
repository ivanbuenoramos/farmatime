const { HttpsError } = require('firebase-functions/v2/https');
const { db } = require('../config/firebase');
const logger = require('firebase-functions/logger');

function assertAuth(req) {
  if (!req.auth) {
    throw new HttpsError('unauthenticated', 'Login requerido');
  }
}

async function assertCompanyAccount(uid, companyId) {
  const uidStr = String(uid || '').trim();
  const cidStr = String(companyId || '').trim();

  logger.info('[assertCompanyAccount]', { uid: uidStr, companyId: cidStr });
  if (!uidStr || !cidStr) throw new HttpsError('invalid-argument', 'uid/companyId vacío');

  const snap = await db.collection('companies').doc(cidStr).get();
  if (!snap.exists) throw new HttpsError('not-found', 'Empresa no existe');

  if (uidStr !== cidStr) {
    throw new HttpsError('permission-denied', 'Solo la cuenta de empresa puede gestionar la facturación');
  }

  logger.info('[assertCompanyAccount] OK');
}

module.exports = { assertAuth, assertCompanyAccount };
