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

      const uid = afterData.authUid || afterData.uid || event.params.employeeId;
      const companyId = afterData.companyId || null;

      if (!uid) {
        logger.error('[handleEmployeeDeletion] sin uid para purgar', afterData);
        return;
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
