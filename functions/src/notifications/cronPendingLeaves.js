// functions/src/notifications/cronPendingLeaves.js
//
// #18 Recordatorio de solicitudes de ausencia sin revisar (cron diario 09:00).
// Agrupa las solicitudes en estado 'requested' por empresa y notifica el conteo.

const { onSchedule } = require('firebase-functions/v2/scheduler');
const { logger } = require('firebase-functions');
const { db } = require('../config/firebase');
const { sendPushToUsers } = require('./sendPush');

exports.cronPendingLeaves = onSchedule(
    {
      region: 'europe-west1',
      schedule: 'every day 09:00',
      timeZone: 'Europe/Madrid',
    },
    async () => {
      const snap = await db
          .collection('time_off_requests')
          .where('status', '==', 'requested')
          .get();

      // Cuenta pendientes por empresa.
      const byCompany = new Map();
      for (const doc of snap.docs) {
        const companyId = (doc.data() || {}).companyId;
        if (!companyId) continue;
        byCompany.set(companyId, (byCompany.get(companyId) || 0) + 1);
      }

      let sent = 0;
      for (const [companyId, count] of byCompany.entries()) {
        await sendPushToUsers({
          uids: [companyId],
          title: 'Solicitudes pendientes',
          body: count === 1 ?
            'Tienes 1 solicitud de ausencia sin revisar' :
            `Tienes ${count} solicitudes de ausencia sin revisar`,
          data: { type: 'leave_request' },
        });
        sent++;
      }

      logger.info(`cronPendingLeaves: ${sent} empresa(s) notificadas`);
    },
);
