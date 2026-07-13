// functions/src/notifications/onClockRecordEdited.js
//
// Trigger: un fichaje ha sido editado.
//   clockRecords/{recordId}
//
// - editedBy === 'company'  → notifica al EMPLEADO (su fichaje fue corregido).
// - editedBy === 'employee' → notifica a la EMPRESA (auditoría).
//
// Solo dispara cuando la edición es nueva (cambia editedAt o isEdited pasa a true),
// para no notificar en cada escritura del documento (p.ej. al cerrar el fichaje).

const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { logger } = require('firebase-functions');
const { sendPushToUsers } = require('./sendPush');
const { employeeName } = require('./names');

/**
 * Timestamp → millis comparables (o null).
 * @param {*} v
 * @return {?number}
 */
function toMillis(v) {
  if (!v) return null;
  if (typeof v.toMillis === 'function') return v.toMillis();
  if (v._seconds != null) return v._seconds * 1000;
  return null;
}

/**
 * Fecha del fichaje en formato corto dd/MM (zona Madrid).
 * @param {*} clockIn
 * @return {string}
 */
function clockDateLabel(clockIn) {
  const ms = toMillis(clockIn);
  if (!ms) return '';
  try {
    return new Date(ms).toLocaleDateString('es-ES', {
      timeZone: 'Europe/Madrid',
      day: '2-digit',
      month: '2-digit',
    });
  } catch (_) {
    return '';
  }
}

exports.onClockRecordEdited = onDocumentWritten(
    'clockRecords/{recordId}',
    async (event) => {
      const before = event.data?.before?.data() || null;
      const after = event.data?.after?.data() || null;

      if (!after) return; // borrado: no notificamos
      if (after.isEdited !== true) return; // solo ediciones

      // ¿Es una edición nueva? Comparamos la marca editedAt.
      const beforeEdited = before && before.isEdited === true;
      const beforeAt = toMillis(before && before.editedAt);
      const afterAt = toMillis(after.editedAt);
      const isNewEdit = !beforeEdited || beforeAt !== afterAt;
      if (!isNewEdit) return;

      const employeeId = after.employeeId;
      const companyId = after.companyId;
      const editedBy = after.editedBy;
      const reason = (after.editReason || '').toString();
      const dateLabel = clockDateLabel(after.clockIn);

      if (editedBy === 'company') {
        await sendPushToUsers({
          uids: [employeeId],
          title: 'Tu fichaje fue editado',
          body: `La empresa modificó tu fichaje${dateLabel ? ` del ${dateLabel}` : ''}` +
            `${reason ? ` · ${reason}` : ''}`,
          data: { type: 'clock_alert', recordId: event.params.recordId },
        });
        logger.info(`onClockRecordEdited: edición empresa → empleado ${employeeId}`);
      } else if (editedBy === 'employee') {
        const name = await employeeName(employeeId);
        await sendPushToUsers({
          uids: [companyId],
          title: 'Fichaje editado por un empleado',
          body: `${name} modificó su fichaje${dateLabel ? ` del ${dateLabel}` : ''}` +
            `${reason ? ` · ${reason}` : ''}`,
          data: { type: 'clock_alert', recordId: event.params.recordId, employeeId },
        });
        logger.info(`onClockRecordEdited: edición empleado → empresa ${companyId}`);
      }
    },
);
