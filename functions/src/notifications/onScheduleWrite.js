// functions/src/notifications/onScheduleWrite.js
//
// Trigger: cambios en el horario de un empleado para un mes.
//   employee_schedule_months/{docId}
//
// El documento agrupa los días de un mes (mapa `entries`) para un empleado.
// La empresa edita estos documentos; el empleado nunca escribe aquí. Cuando
// cambian las entradas notificamos UNA vez al empleado afectado.

const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { logger } = require('firebase-functions');
const { sendPushToUsers } = require('./sendPush');

const MONTH_NAMES = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/**
 * 'yyyy-MM' → 'mes de yyyy' (ej. '2026-06' → 'junio de 2026').
 * @param {string} month
 * @return {string}
 */
function monthLabel(month) {
  if (typeof month !== 'string' || !month.includes('-')) return month || '';
  const [y, m] = month.split('-');
  const idx = parseInt(m, 10) - 1;
  const name = MONTH_NAMES[idx] || month;
  return `${name} de ${y}`;
}

/**
 * ¿Cambió realmente el mapa de entradas? Evita notificar por updatedAt.
 * @param {Object} before
 * @param {Object} after
 * @return {boolean}
 */
function entriesChanged(before, after) {
  const a = JSON.stringify((before && before.entries) || {});
  const b = JSON.stringify((after && after.entries) || {});
  return a !== b;
}

exports.onScheduleWrite = onDocumentWritten(
    'employee_schedule_months/{docId}',
    async (event) => {
      const before = event.data?.before?.data() || null;
      const after = event.data?.after?.data() || null;

      if (!after) return; // borrado del mes completo: no notificamos
      if (!entriesChanged(before, after)) return;

      const employeeId = after.employeeId;
      if (!employeeId) return;

      const month = monthLabel(after.month);

      await sendPushToUsers({
        uids: [employeeId],
        title: 'Tu horario ha cambiado',
        body: month ?
        `Se ha actualizado tu turno de ${month}` :
        'Se ha actualizado tu turno',
        data: {
          type: 'schedule_change',
          month: after.month || '',
        },
      });

      logger.info(`onScheduleWrite: horario actualizado → empleado ${employeeId}`);
    },
);
