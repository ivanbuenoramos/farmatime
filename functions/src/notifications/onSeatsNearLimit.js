// functions/src/notifications/onSeatsNearLimit.js
//
// #28 Plazas cerca del límite: al crear un empleado, si las plazas ocupadas
// alcanzan el 80% (o más) de las contratadas, avisa a la EMPRESA para que
// considere ampliar el plan. Solo cuando hay más de 1 plaza contratada.

const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { logger } = require('firebase-functions');
const { db } = require('../config/firebase');
const { sendPushToUsers } = require('./sendPush');
const { occupiesSeat } = require('../helpers/seatPolicy');

exports.onSeatsNearLimit = onDocumentCreated(
    'employees/{employeeId}',
    async (event) => {
      const emp = event.data?.data() || {};
      // Ignorar el doc temporal de reserva (createEmployeeAccount lo borra al
      // migrar al UID de Auth real). Sin esto contábamos plazas con +1 ficticia
      // y disparábamos avisos cuando aún no había alta completa.
      if (emp._pendingReservation) return;
      const companyId = emp.companyId;
      if (!companyId) return;

      const companySnap = await db.collection('companies').doc(companyId).get();
      if (!companySnap.exists) return;
      const company = companySnap.data() || {};

      // Si la suscripción ya no está pagada (cancelada/expirada/etc.) no tiene
      // sentido sugerir "ampliar plan": la empresa verá el bloqueo de billing.
      const PAID = new Set(['active', 'in_grace_period', 'in_billing_retry', 'trialing']);
      if (!PAID.has(company.billingStatus)) return;

      const contracted = typeof company.contractedSeats === 'number' ?
        company.contractedSeats : 1;
      if (contracted <= 1) return; // plan gratuito: no avisamos

      // Cuenta plazas ocupadas (misma definición que createEmployeeAccount).
      const empSnap = await db
          .collection('employees')
          .where('companyId', '==', companyId)
          .get();
      const occupied = empSnap.docs.filter(
          (d) => occupiesSeat((d.data() || {}).accountStatus),
      ).length;

      const ratio = occupied / contracted;
      // Avisa solo al cruzar el 80% (y no cuando ya está al 100%, que tiene su
      // propio control en la pantalla de suscripción).
      if (ratio >= 0.8 && occupied < contracted) {
        await sendPushToUsers({
          uids: [companyId],
          title: 'Casi sin plazas libres',
          body: `Usas ${occupied} de ${contracted} plazas. Considera ampliar tu plan.`,
          data: { type: 'billing' },
        });
        logger.info(
            `onSeatsNearLimit: ${occupied}/${contracted} → empresa ${companyId}`,
        );
      }
    },
);
