// functions/src/notifications/cronClockAlerts.js
//
// Alertas de fichaje (cron, cada 15 min):
//
//   #1 Empleado sin fichar: su turno empezó hace >=30 min y no tiene ningún
//      fichaje hoy → notifica a la EMPRESA.
//   #3 Olvidó fichar salida: tiene un fichaje abierto (clockOut null) y su turno
//      terminó hace >=30 min → notifica al EMPLEADO.

const { onSchedule } = require('firebase-functions/v2/scheduler');
const { logger } = require('firebase-functions');
const { admin, db } = require('../config/firebase');
const { sendPushToUsers } = require('./sendPush');
const { resolveDayShift, toMinutes, ymdMadrid } = require('./scheduleResolver');

const LATE_THRESHOLD_MIN = 30;

/**
 * Minutos desde medianoche AHORA en zona Madrid.
 * @param {Date} date
 * @return {number}
 */
function nowMinutesMadrid(date) {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Europe/Madrid',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).formatToParts(date);
  const h = parseInt(parts.find((p) => p.type === 'hour').value, 10);
  const m = parseInt(parts.find((p) => p.type === 'minute').value, 10);
  return h * 60 + m;
}

/**
 * Inicio del día (00:00 Madrid) de una fecha, como Timestamp Firestore.
 * @param {Date} date
 * @return {*}
 */
function startOfDayTs(date) {
  const ymd = ymdMadrid(date);
  // Madrid es UTC+1/+2; usamos un margen amplio leyendo desde 00:00 UTC del día.
  return admin.firestore.Timestamp.fromDate(new Date(`${ymd}T00:00:00Z`));
}

/** Empleados activos (uid, companyId). */
async function activeEmployees() {
  const snap = await db
      .collection('employees')
      .where('accountStatus', '==', 'active')
      .get();
  return snap.docs.map((d) => ({
    uid: d.id,
    companyId: (d.data() || {}).companyId,
    name: (d.data() || {}).name || 'Un empleado',
  }));
}

exports.cronClockAlerts = onSchedule(
    {
      region: 'europe-west1',
      schedule: 'every 15 minutes',
      timeZone: 'Europe/Madrid',
    },
    async () => {
      const now = new Date();
      const nowMin = nowMinutesMadrid(now);
      const dayStart = startOfDayTs(now);
      const employees = await activeEmployees();

      let missing = 0;
      let forgotOut = 0;

      for (const emp of employees) {
        if (!emp.companyId) continue;

        const shift = await resolveDayShift({
          companyId: emp.companyId,
          employeeId: emp.uid,
          date: now,
        });
        if (shift.type !== 'work' || !shift.start) continue;

        const startMin = toMinutes(shift.start);
        const endMin = toMinutes(shift.end);

        // Fichajes de hoy del empleado.
        const recSnap = await db
            .collection('clockRecords')
            .where('employeeId', '==', emp.uid)
            .where('clockIn', '>=', dayStart)
            .get();
        const records = recSnap.docs.map((d) => d.data() || {});

        // #1 Sin fichar: turno empezó hace >=30 min y no hay ningún fichaje hoy.
        if (
          startMin != null &&
          nowMin - startMin >= LATE_THRESHOLD_MIN &&
          records.length === 0
        ) {
          await sendPushToUsers({
            uids: [emp.companyId],
            title: 'Empleado sin fichar',
            body: `${emp.name} no ha fichado (turno desde las ${fmt(shift.start)})`,
            data: { type: 'clock_alert', employeeId: emp.uid },
          });
          missing++;
          continue;
        }

        // #3 Olvidó la salida: hay fichaje abierto y el turno acabó hace >=30 min.
        const openRecord = records.find((r) => r.clockOut == null);
        if (
          openRecord &&
          endMin != null &&
          nowMin - endMin >= LATE_THRESHOLD_MIN
        ) {
          await sendPushToUsers({
            uids: [emp.uid],
            title: '¿Olvidaste fichar la salida?',
            body: `Tu turno terminó a las ${fmt(shift.end)} y sigues fichado`,
            data: { type: 'clock_alert' },
          });
          forgotOut++;
        }
      }

      logger.info(
          `cronClockAlerts: ${missing} sin-fichar, ${forgotOut} sin-salida`,
      );
    },
);

/**
 * 'HHmm' → 'HH:mm'.
 * @param {*} hhmm
 * @return {string}
 */
function fmt(hhmm) {
  const s = String(hhmm || '').padStart(4, '0');
  return `${s.substring(0, 2)}:${s.substring(2, 4)}`;
}
