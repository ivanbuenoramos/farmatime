// functions/src/notifications/cronShiftReminder.js
//
// Recordatorios de turno (cron).
//
//   cronShiftStartReminder  (cada 15 min): "Tu turno empieza en ~15 min".
//   cronTomorrowShift       (cada día 20:00): "Mañana trabajas HH:MM-HH:MM".
//
// Ambos resuelven el turno efectivo de cada empleado activo con scheduleResolver.

const { onSchedule } = require('firebase-functions/v2/scheduler');
const { logger } = require('firebase-functions');
const { db } = require('../config/firebase');
const { sendPushToUsers } = require('./sendPush');
const { resolveDayShift, toMinutes } = require('./scheduleResolver');

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
 * 'HHmm' → 'HH:mm' para mostrar.
 * @param {*} hhmm
 * @return {string}
 */
function fmt(hhmm) {
  const s = String(hhmm || '').padStart(4, '0');
  return `${s.substring(0, 2)}:${s.substring(2, 4)}`;
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
  }));
}

// ── Recordatorio: el turno empieza en ~15 minutos ──
exports.cronShiftStartReminder = onSchedule(
    {
      region: 'europe-west1',
      schedule: 'every 15 minutes',
      timeZone: 'Europe/Madrid',
    },
    async () => {
      const now = new Date();
      const nowMin = nowMinutesMadrid(now);
      const employees = await activeEmployees();
      let sent = 0;

      for (const emp of employees) {
        if (!emp.companyId) continue;
        const shift = await resolveDayShift({
          companyId: emp.companyId,
          employeeId: emp.uid,
          date: now,
        });
        if (shift.type !== 'work' || !shift.start) continue;

        const startMin = toMinutes(shift.start);
        if (startMin == null) continue;

        // Dispara si el inicio cae en la ventana (now+10, now+20]. La función
        // corre cada 15 min, así que cada turno entra como mucho en una ejecución.
        const delta = startMin - nowMin;
        if (delta > 10 && delta <= 20) {
          await sendPushToUsers({
            uids: [emp.uid],
            title: 'Tu turno está por empezar',
            body: `Empiezas a las ${fmt(shift.start)}`,
            data: { type: 'schedule_change' },
          });
          sent++;
        }
      }
      logger.info(`cronShiftStartReminder: ${sent} recordatorio(s) enviados`);
    },
);

// ── Recordatorio: "mañana trabajas" (la tarde anterior) ──
exports.cronTomorrowShift = onSchedule(
    {
      region: 'europe-west1',
      schedule: 'every day 20:00',
      timeZone: 'Europe/Madrid',
    },
    async () => {
      const tomorrow = new Date(Date.now() + 24 * 60 * 60 * 1000);
      const employees = await activeEmployees();
      let sent = 0;

      for (const emp of employees) {
        if (!emp.companyId) continue;
        const shift = await resolveDayShift({
          companyId: emp.companyId,
          employeeId: emp.uid,
          date: tomorrow,
        });
        if (shift.type !== 'work' || !shift.start) continue;

        const horas = shift.end ?
          `${fmt(shift.start)}-${fmt(shift.end)}` :
          `desde las ${fmt(shift.start)}`;
        await sendPushToUsers({
          uids: [emp.uid],
          title: 'Mañana trabajas',
          body: `Tu turno de mañana: ${horas}`,
          data: { type: 'schedule_change' },
        });
        sent++;
      }
      logger.info(`cronTomorrowShift: ${sent} aviso(s) enviados`);
    },
);
