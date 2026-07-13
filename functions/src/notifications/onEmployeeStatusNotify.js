// functions/src/notifications/onEmployeeStatusNotify.js
//
// Trigger: cambio de estado de cuenta de un empleado.
//   employees/{employeeId}
//
// - pending → active : el empleado activó su cuenta → notifica a la EMPRESA.
// - * → deleted      : la empresa eliminó al empleado → notifica al EMPLEADO.
//
// Nota: existe otro trigger (onEmployeeStatusChanged / handleEmployeeDeletion)
// sobre la misma colección que borra la cuenta de Auth al pasar a 'deleted'.
// Este es independiente y solo envía notificaciones push; conviven sin problema.

const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { logger } = require('firebase-functions');
const { sendPushToUsers } = require('./sendPush');

exports.onEmployeeStatusNotify = onDocumentUpdated(
    'employees/{employeeId}',
    async (event) => {
      const before = event.data?.before?.data() || null;
      const after = event.data?.after?.data() || null;
      if (!before || !after) return;

      const beforeStatus = before.accountStatus;
      const afterStatus = after.accountStatus;
      if (beforeStatus === afterStatus) return;

      const employeeId = event.params.employeeId;
      const companyId = after.companyId;
      const name = after.name || 'Un empleado';

      // ── Activación: el empleado entró y puso su contraseña ──
      if (beforeStatus === 'pending' && afterStatus === 'active') {
        await sendPushToUsers({
          uids: [companyId],
          title: 'Empleado activado',
          body: `${name} ya ha activado su cuenta`,
          data: { type: 'employee_active', employeeId },
        });
        logger.info(`onEmployeeStatusNotify: activación → empresa ${companyId}`);
        return;
      }

      // ── Eliminación: la empresa eliminó al empleado ──
      if (afterStatus === 'deleted') {
        await sendPushToUsers({
          uids: [employeeId],
          title: 'Tu cuenta ha sido desactivada',
          body: 'Tu acceso a Farmatime ha sido retirado por la empresa',
          data: { type: 'employee_deleted' },
        });
        logger.info(`onEmployeeStatusNotify: eliminación → empleado ${employeeId}`);
      }
    },
);
