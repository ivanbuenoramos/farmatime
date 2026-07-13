// iap/billingGraceCron.js
// Cron diario que bloquea a los empleados de farmacias morosas cuando han
// pasado más de 30 días desde la cancelación.
//
// Comportamiento:
//   - Día 0..29 tras canceledAt: empleados siguen operativos (gracia in-app),
//     solo la cuenta de farmacia ve la pantalla de renovación.
//   - Día 30+: este cron pone a los empleados en estado 'disabled' y baja
//     contractedSeats a 1.
const { onSchedule } = require('firebase-functions/v2/scheduler');
const logger = require('firebase-functions/logger');
const { db, admin } = require('../config/firebase');
const { updateEmployeesForBillingState, GRACE_MS } = require('../helpers/billingEmployees');
const { sendPushToUsers } = require('../notifications/sendPush');

/**
 * Notifica a empresa y empleados que el acceso ha quedado bloqueado (día 30+).
 * @param {string} companyId
 * @return {Promise<void>}
 */
async function notifyBlocked(companyId) {
  try {
    // Empresa.
    await sendPushToUsers({
      uids: [companyId],
      title: 'Acceso bloqueado',
      body: 'Tu suscripción ha expirado y tus empleados ya no pueden trabajar. ' +
        'Renueva para restaurar el acceso.',
      data: { type: 'billing', billingStatus: 'blocked' },
    });
    // Empleados de la empresa.
    const empSnap = await db
        .collection('employees')
        .where('companyId', '==', companyId)
        .get();
    const empIds = empSnap.docs
        .map((d) => d.id)
        .filter((id) => {
          const st = (empSnap.docs.find((x) => x.id === id).data() || {}).accountStatus;
          return st !== 'deleted';
        });
    if (empIds.length) {
      await sendPushToUsers({
        uids: empIds,
        title: 'Acceso suspendido',
        body: 'Tu farmacia ha perdido el acceso. Contacta con el administrador.',
        data: { type: 'billing' },
      });
    }
  } catch (e) {
    logger.warn('[iap_billingGraceCron] error notificando bloqueo', e);
  }
}

const CANCELED_STATUSES = ['canceled', 'expired', 'revoked', 'on_hold', 'paused'];

exports.iap_billingGraceCron = onSchedule(
    {
      region: 'europe-west1',
      schedule: 'every day 03:00',
      timeZone: 'Europe/Madrid',
    },
    async () => {
      const cutoffMs = Date.now() - GRACE_MS;
      const cutoffTs = admin.firestore.Timestamp.fromMillis(cutoffMs);

      // Firestore no soporta `where in` + `where <` con los índices por defecto
      // sin un compuesto, así que iteramos por estado.
      let processed = 0;
      let blocked = 0;

      for (const status of CANCELED_STATUSES) {
        const snap = await db
            .collection('companies')
            .where('billingStatus', '==', status)
            .where('subscription.canceledAt', '<=', cutoffTs)
            .get();

        for (const doc of snap.docs) {
          processed++;
          const data = doc.data() || {};
          const currentSeats = typeof data.contractedSeats === 'number' ? data.contractedSeats : 1;

          // Bajamos a 1 plaza para que updateEmployeesForBillingState aplique
          // el bloqueo total (allowedActive=1 + blockEmployees=true al estar
          // fuera de la ventana de gracia).
          if (currentSeats !== 1) {
            await doc.ref.set(
                {
                  contractedSeats: 1,
                  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                },
                { merge: true },
            );
          }

          await updateEmployeesForBillingState(doc.id);
          await notifyBlocked(doc.id);
          blocked++;
        }
      }

      logger.info('[iap_billingGraceCron] done', { processed, blocked, cutoffMs });
    },
);
