// functions/src/notifications/onRecurringRuleWrite.js
//
// Trigger: regla de horario recurrente creada, editada o eliminada.
//   employee_schedule_rules/{ruleId}
//
// - Creación o edición (active: true)  → "Tu horario recurrente cambió: L-V 08:00-16:00".
// - Soft delete (active pasa a false)  → "Tu horario recurrente fue eliminado".
// En ambos casos se notifica al EMPLEADO (employeeId).

const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { logger } = require('firebase-functions');
const { sendPushToUsers } = require('./sendPush');

const WD = { 1: 'L', 2: 'M', 3: 'X', 4: 'J', 5: 'V', 6: 'S', 7: 'D' };

/**
 * [1,2,3,4,5] → 'L, M, X, J, V'.
 * @param {number[]} weekdays
 * @return {string}
 */
function weekdaysLabel(weekdays) {
  if (!Array.isArray(weekdays) || !weekdays.length) return '';
  return [...weekdays].sort((a, b) => a - b).map((d) => WD[d] || '?').join(', ');
}

/**
 * 'HHmm' → 'HH:mm'.
 * @param {string} v
 * @return {string}
 */
function hhmm(v) {
  const s = (v || '').toString().padStart(4, '0');
  return `${s.substring(0, 2)}:${s.substring(2, 4)}`;
}

exports.onRecurringRuleWrite = onDocumentWritten(
    'employee_schedule_rules/{ruleId}',
    async (event) => {
      const before = event.data?.before?.data() || null;
      const after = event.data?.after?.data() || null;

      if (!after) return; // borrado físico: no notificamos
      const employeeId = after.employeeId;
      if (!employeeId) return;

      const wasActive = before ? before.active !== false : false;
      const isActive = after.active !== false;

      // ── Eliminación (soft delete): active pasa de true a false ──
      if (wasActive && !isActive) {
        const dias = weekdaysLabel(after.weekdays);
        await sendPushToUsers({
          uids: [employeeId],
          title: 'Horario recurrente eliminado',
          body: `Se ha eliminado tu horario recurrente${dias ? ` (${dias})` : ''}`,
          data: { type: 'schedule_change', ruleId: event.params.ruleId },
        });
        logger.info(`onRecurringRuleWrite: regla eliminada → empleado ${employeeId}`);
        return;
      }

      // Si la regla está inactiva y sigue inactiva, no notificamos.
      if (!isActive) return;

      // ── Creación o edición de una regla activa ──
      // Evita notificar si nada relevante cambió (p.ej. solo updatedAt).
      if (before) {
        const relevant = ['start', 'end', 'weekdays', 'startsOn', 'endsOn', 'active'];
        const same = relevant.every(
            (k) => JSON.stringify(before[k]) === JSON.stringify(after[k]),
        );
        if (same) return;
      }

      const dias = weekdaysLabel(after.weekdays);
      const horas = `${hhmm(after.start)}-${hhmm(after.end)}`;

      await sendPushToUsers({
        uids: [employeeId],
        title: 'Tu horario recurrente cambió',
        body: `${dias ? `${dias} · ` : ''}${horas}`,
        data: { type: 'schedule_change', ruleId: event.params.ruleId },
      });
      logger.info(`onRecurringRuleWrite: regla actualizada → empleado ${employeeId}`);
    },
);
