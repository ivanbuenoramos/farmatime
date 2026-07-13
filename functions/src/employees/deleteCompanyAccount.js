// deleteCompanyAccount.js
// Borra de forma permanente la cuenta de una empresa y TODOS sus datos
// asociados (empleados, fichajes, reportes, horarios, ausencias, chats, tokens,
// Storage y cuentas de Auth). GDPR / derecho al olvido.
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
const { assertCompanyAccount } = require('../helpers/assertions');
const { deleteCompanyData } = require('../helpers/cascadeDelete');

exports.deleteCompanyAccount = onCall(
    { region: 'europe-west1', timeoutSeconds: 540, memory: '512MiB' },
    async (request) => {
      if (!request.auth) throw new HttpsError('unauthenticated', 'Login requerido');
      const callerUid = request.auth.uid;
      const companyId = String(request.data?.companyId || '').trim();

      if (!companyId) {
        throw new HttpsError('invalid-argument', 'companyId requerido');
      }

      // Solo la propia cuenta de empresa puede eliminarse a sí misma
      // (assertCompanyAccount exige uid === companyId).
      await assertCompanyAccount(callerUid, companyId);

      logger.info('[deleteCompanyAccount] START', { companyId });
      try {
        await deleteCompanyData(companyId);
      } catch (e) {
        logger.error('[deleteCompanyAccount] ERROR', { companyId, msg: e?.message, stack: e?.stack });
        throw new HttpsError('internal', 'No se pudo completar el borrado');
      }
      logger.info('[deleteCompanyAccount] DONE', { companyId });
      return { deleted: true };
    },
);
