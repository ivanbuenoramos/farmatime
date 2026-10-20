const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const logger = require('firebase-functions/logger');
const { deleteEmployeeData } = require('../helpers/cascadeDelete');

// Cuando un empleado pasa a 'deleted' purgamos TODOS sus datos en cascada:
// doc de empleado, fichajes (+ auditLog), reportes, horarios, ausencias, tokens
// FCM, conversaciones (DMs borrados, retirado de grupos), Storage y cuenta Auth.
//
// NOTA LEGAL: esto borra también el registro horario. El RD 8/2019 obliga a
// conservar el registro de jornada 4 años; si la empresa necesita preservarlo,
// debe exportar/archivar los reportes ANTES de eliminar al empleado. La purga
// total es una decisión explícita de producto (derecho al olvido inmediato).
exports.handleEmployeeDeletion = onDocumentUpdated(
    {
      document: 'employees/{employeeId}',
      region: 'europe-west1',
      timeoutSeconds: 540,
      memory: '512MiB',
    },
    async (event) => {
      const beforeData = event.data.before.data();
      const afterData = event.data.after.data();

      if (!beforeData || !afterData) return;

      const beforeStatus = beforeData.accountStatus;
      const afterStatus = afterData.accountStatus;

      // Solo actuamos en la transición → 'deleted'.
      if (beforeStatus === afterStatus) return;
      if (afterStatus !== 'deleted') return;

      // SEGURIDAD: el uid a purgar es el id del documento (employees/{uid} lo
      // crea el backend con el uid de Auth). Nunca se toma de un campo del doc
      // (uid/authUid), que lo puede escribir el cliente: una empresa podría
      // apuntar a otro uid y borrar la cuenta y los datos de un tercero.
      const uid = event.params.employeeId;
      const companyId = afterData.companyId || null;

      if (afterData.uid && afterData.uid !== uid) {
        logger.warn('[handleEmployeeDeletion] campo uid distinto del id del doc; se ignora', {
          docId: uid, fieldUid: afterData.uid,
        });
      }

      try {
        await deleteEmployeeData(uid, { companyId });
        logger.info('[handleEmployeeDeletion] empleado purgado', { uid, companyId });
      } catch (err) {
        logger.error('[handleEmployeeDeletion] error en cascada', {
          uid,
          msg: err?.message,
          stack: err?.stack,
        });
      }
    },
);
