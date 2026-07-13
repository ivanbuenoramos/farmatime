// functions/src/notifications/onTimeOffWrite.js
//
// Trigger: creación o cambio de estado de una solicitud de ausencia.
//   time_off_requests/{requestId}
//
// Eventos cubiertos:
//   - Creación (status 'requested')        → notifica a la EMPRESA (companyId).
//   - Empresa aprueba/rechaza/propone       → notifica al EMPLEADO (employeeId).
//   - Empleado acepta/rechaza propuesta     → notifica a la EMPRESA.

const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { logger } = require('firebase-functions');
const { sendPushToUsers } = require('./sendPush');
const { employeeName } = require('./names');

const TYPE_LABEL = { vacation: 'vacaciones', personal: 'asuntos propios' };

function typeLabel(code) {
  return TYPE_LABEL[code] || 'ausencia';
}

/**
 * Resumen corto de fechas (ej. "2026-06-01 → 2026-06-03 (3 días)").
 * @param {string[]} dates
 * @return {string}
 */
function datesSummary(dates) {
  if (!Array.isArray(dates) || !dates.length) return '';
  const sorted = [...dates].sort();
  const n = sorted.length;
  if (n === 1) return sorted[0];
  return `${sorted[0]} → ${sorted[n - 1]} (${n} días)`;
}

exports.onTimeOffWrite = onDocumentWritten(
    'time_off_requests/{requestId}',
    async (event) => {
      const before = event.data?.before?.data() || null;
      const after = event.data?.after?.data() || null;

      // Borrado: nada que notificar.
      if (!after) return;

      const beforeStatus = before?.status || null;
      const afterStatus = after.status;

      // Si el estado no cambió (p.ej. edición de nota), no notificamos.
      if (before && beforeStatus === afterStatus) return;

      const companyId = after.companyId;
      const employeeId = after.employeeId;
      const type = typeLabel(after.type);
      const dates = datesSummary(
      after.proposedDates && after.proposedDates.length ?
        after.proposedDates :
        after.dates,
      );
      const companyNote = (after.companyNote || '').toString();

      // ── Caso 1: nueva solicitud (creación con estado requested) ──
      const isNew = !before;
      if (isNew && afterStatus === 'requested') {
        const name = await employeeName(employeeId);
        await sendPushToUsers({
          uids: [companyId],
          title: 'Nueva solicitud de ausencia',
          body: `${name} solicita ${type}${dates ? ` · ${dates}` : ''}`,
          data: { type: 'leave_request', requestId: event.params.requestId, employeeId },
        });
        logger.info(`onTimeOffWrite: nueva solicitud → empresa ${companyId}`);
        return;
      }

      // ── Caso 1b: el empleado cancela su solicitud → notificar a la empresa ──
      if (afterStatus === 'cancelled') {
        const name = await employeeName(employeeId);
        await sendPushToUsers({
          uids: [companyId],
          title: 'Solicitud cancelada',
          body: `${name} canceló su solicitud de ${type}`,
          data: { type: 'leave_request', requestId: event.params.requestId, employeeId },
        });
        logger.info(`onTimeOffWrite: solicitud cancelada → empresa ${companyId}`);
        return;
      }

      // ── Caso 2: empresa decide → notificar al empleado ──
      if (afterStatus === 'approved' || afterStatus === 'rejected' || afterStatus === 'proposed') {
      // Si la última decisión la tomó el empleado (aceptar/rechazar propuesta),
      // el destinatario es la empresa, no el empleado.
        const decidedByEmployee = after.decidedBy === employeeId;
        if (decidedByEmployee) {
          const verb = afterStatus === 'approved' ? 'aceptó' : 'rechazó';
          const name = await employeeName(employeeId);
          await sendPushToUsers({
            uids: [companyId],
            title: 'Respuesta a tu propuesta',
            body: `${name} ${verb} la propuesta de ${type}`,
            data: { type: 'leave_request', requestId: event.params.requestId, employeeId },
          });
          logger.info(`onTimeOffWrite: empleado respondió → empresa ${companyId}`);
          return;
        }

        let title;
        let body;
        if (afterStatus === 'approved') {
          title = 'Solicitud aprobada';
          body = `Tu ${type}${dates ? ` (${dates})` : ''} ha sido aprobada`;
        } else if (afterStatus === 'rejected') {
          title = 'Solicitud rechazada';
          body = `Tu ${type} ha sido rechazada${companyNote ? ` · ${companyNote}` : ''}`;
        } else {
          title = 'Propuesta de fechas';
          body = `Te proponen otras fechas para tu ${type}${dates ? `: ${dates}` : ''}`;
        }

        await sendPushToUsers({
          uids: [employeeId],
          title,
          body,
          data: { type: 'leave_status', requestId: event.params.requestId },
        });
        logger.info(`onTimeOffWrite: decisión '${afterStatus}' → empleado ${employeeId}`);
      }
    },
);
