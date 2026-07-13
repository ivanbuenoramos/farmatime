// functions/src/notifications/scheduleResolver.js
//
// Resuelve el turno efectivo de un empleado para una fecha concreta, replicando
// la lógica del cliente:
//   1) Override del mes  (employee_schedule_months, entries[yyyy-MM-dd])
//   2) Regla recurrente  (employee_schedule_rules: weekday + rango + active)
//   3) Si nada aplica → libre.
//
// Devuelve { type, start, end } con start/end en 'HHmm' (o null si no es laboral).

const { db } = require('../config/firebase');

const MS_DAY = 24 * 60 * 60 * 1000;

/**
 * 'HHmm'|'HH:mm' → minutos desde medianoche, o null.
 * @param {*} hhmm
 * @return {?number}
 */
function toMinutes(hhmm) {
  if (hhmm == null) return null;
  const digits = String(hhmm).replace(/[^0-9]/g, '');
  if (digits.length !== 4) return null;
  const h = parseInt(digits.substring(0, 2), 10);
  const m = parseInt(digits.substring(2, 4), 10);
  if (isNaN(h) || isNaN(m) || h > 23 || m > 59) return null;
  return h * 60 + m;
}

/**
 * Date → 'yyyy-MM-dd' en zona Madrid.
 * @param {Date} date
 * @return {string}
 */
function ymdMadrid(date) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Madrid',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);
  const get = (t) => parts.find((p) => p.type === t).value;
  return `${get('year')}-${get('month')}-${get('day')}`;
}

/**
 * weekday 1..7 (Lun..Dom) de una fecha en zona Madrid.
 * @param {Date} date
 * @return {?number}
 */
function weekdayMadrid(date) {
  const wd = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Europe/Madrid',
    weekday: 'short',
  }).format(date);
  const map = { Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7 };
  return map[wd] || null;
}

/**
 * Timestamp Firestore → millis (o null).
 * @param {*} v
 * @return {?number}
 */
function tsMillis(v) {
  if (!v) return null;
  if (typeof v.toMillis === 'function') return v.toMillis();
  if (v._seconds != null) return v._seconds * 1000;
  return null;
}

/**
 * Turno efectivo de un empleado en una fecha.
 * @param {Object} p
 * @param {string} p.companyId
 * @param {string} p.employeeId
 * @param {Date} p.date
 * @return {Promise<{type: string, start: ?string, end: ?string}>}
 */
async function resolveDayShift({ companyId, employeeId, date }) {
  const ymd = ymdMadrid(date);
  const month = ymd.substring(0, 7);

  // 1) Override del mes
  const monthDocId = `${companyId}__${employeeId}__${month}`;
  const monthSnap = await db
      .collection('employee_schedule_months')
      .doc(monthDocId)
      .get();
  if (monthSnap.exists) {
    const entries = monthSnap.get('entries') || {};
    const e = entries[ymd];
    if (e && e.type) {
      return { type: e.type, start: e.start || null, end: e.end || null };
    }
  }

  // 2) Regla recurrente
  const weekday = weekdayMadrid(date);
  const dayMs = new Date(`${ymd}T00:00:00Z`).getTime();
  const rulesSnap = await db
      .collection('employee_schedule_rules')
      .where('companyId', '==', companyId)
      .where('employeeId', '==', employeeId)
      .get();

  for (const doc of rulesSnap.docs) {
    const r = doc.data() || {};
    if (r.active === false) continue;
    const weekdays = Array.isArray(r.weekdays) ? r.weekdays : [];
    if (!weekdays.includes(weekday)) continue;

    const startsOn = tsMillis(r.startsOn);
    const endsOn = tsMillis(r.endsOn);
    if (startsOn != null && dayMs < startsOn - MS_DAY) continue;
    if (endsOn != null && dayMs > endsOn + MS_DAY) continue;

    return { type: 'work', start: r.start || null, end: r.end || null };
  }

  // 3) Libre
  return { type: 'off', start: null, end: null };
}

module.exports = { resolveDayShift, toMinutes, ymdMadrid, weekdayMadrid };
