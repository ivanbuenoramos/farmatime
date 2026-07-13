// functions/src/notifications/cronBillingReminders.js
//
// Recordatorios de facturación (cron diario 09:00 Madrid):
//
//   #26 Renovación próxima: a 7 días y a 1 día de currentPeriodEnd (autoRenewing).
//   #24 Gracia por expirar: día 25-29 desde subscription.canceledAt.
//
// Todos van a la EMPRESA (id del doc = uid de la farmacia).

const { onSchedule } = require('firebase-functions/v2/scheduler');
const { logger } = require('firebase-functions');
const { db } = require('../config/firebase');
const { sendPushToUsers } = require('./sendPush');

const MS_DAY = 24 * 60 * 60 * 1000;
const GRACE_DAYS = 30;
const PAID = new Set(['active', 'trialing']);
const ENDED = new Set(['canceled', 'expired', 'revoked', 'on_hold', 'paused']);

/**
 * Timestamp → millis (o null).
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
 * Diferencia en días enteros entre dos millis (a - b).
 * @param {number} aMs
 * @param {number} bMs
 * @return {number}
 */
function daysBetween(aMs, bMs) {
  return Math.floor((aMs - bMs) / MS_DAY);
}

exports.cronBillingReminders = onSchedule(
    {
      region: 'europe-west1',
      schedule: 'every day 09:00',
      timeZone: 'Europe/Madrid',
    },
    async () => {
      const now = Date.now();
      const snap = await db.collection('companies').get();
      let renewal = 0;
      let grace = 0;

      for (const doc of snap.docs) {
        const data = doc.data() || {};
        const companyId = doc.id;
        const status = data.billingStatus || 'none';
        const sub = data.subscription || {};

        // #26 Renovación próxima (solo si activo y con renovación automática).
        if (PAID.has(status) && sub.autoRenewing) {
          const endMs = tsMillis(data.currentPeriodEnd);
          if (endMs && endMs > now) {
            const d = daysBetween(endMs, now);
            if (d === 7 || d === 1) {
              await sendPushToUsers({
                uids: [companyId],
                title: 'Tu suscripción se renovará pronto',
                body: d === 1 ?
                  'Tu suscripción se renueva mañana. Revisa tu método de pago.' :
                  'Tu suscripción se renueva en 7 días.',
                data: { type: 'billing', billingStatus: status },
              });
              renewal++;
            }
          }
          continue;
        }

        // #24 Gracia por expirar (día 25-29 tras la cancelación).
        if (ENDED.has(status)) {
          const canceledMs = tsMillis(sub.canceledAt);
          if (canceledMs) {
            const elapsed = daysBetween(now, canceledMs);
            if (elapsed >= 25 && elapsed < GRACE_DAYS) {
              const left = GRACE_DAYS - elapsed;
              await sendPushToUsers({
                uids: [companyId],
                title: 'Tu plazo de renovación termina',
                body: `Quedan ${left} día(s) antes de que tus empleados pierdan ` +
                  'el acceso. Renueva tu suscripción.',
                data: { type: 'billing', billingStatus: status },
              });
              grace++;
            }
          }
        }
      }

      logger.info(`cronBillingReminders: ${renewal} renovación, ${grace} gracia`);
    },
);
