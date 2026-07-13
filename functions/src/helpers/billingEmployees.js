// helpers/billingEmployees.js
const { db, admin } = require('../config/firebase');
const logger = require('firebase-functions/logger');
const { PROMOTABLE } = require('./seatPolicy');

const PAID_STATUSES = new Set(['active', 'in_grace_period', 'in_billing_retry', 'trialing']);

// Ventana de gracia in-app (30 días) tras la cancelación durante la cual los
// empleados siguen operativos aunque la suscripción esté cancelada/expirada.
// Solo a la cuenta de farmacia se le bloquea el acceso desde el primer momento
// (eso se hace en el cliente leyendo subscription.canceledAt).
const GRACE_DAYS = 30;
const GRACE_MS = GRACE_DAYS * 24 * 60 * 60 * 1000;

function isWithinGrace(canceledAtMs) {
  if (!canceledAtMs) return false;
  return Date.now() - canceledAtMs < GRACE_MS;
}

// opts:
//   - overrideAllowedActive: fuerza el nº de plazas activas (cron de gracia).
//   - preferDisableUids: uids que el admin ELIGIÓ desactivar en un downgrade
//     (los pasa iap_verifyPurchase desde el cliente). Van los últimos en la
//     prioridad de promoción, así son ellos los que pierden la plaza y no los
//     más nuevos por createdAt.
async function updateEmployeesForBillingState(companyId, opts = {}) {
  if (!companyId) return;

  const companySnap = await db.collection('companies').doc(companyId).get();
  if (!companySnap.exists) return;

  const company = companySnap.data() || {};
  const billingStatus = company.billingStatus || 'none';

  const contractedSeats = typeof company.contractedSeats === 'number' ? company.contractedSeats : 1;
  const overrideAllowedActive =
    typeof opts.overrideAllowedActive === 'number' ? opts.overrideAllowedActive : null;

  const canceledAt = company.subscription?.canceledAt;
  const canceledAtMs = canceledAt instanceof admin.firestore.Timestamp ? canceledAt.toMillis() : 0;

  // Tres tramos:
  //   1) Pagado: las plazas contratadas siguen activas.
  //   2) No pagado pero dentro de la ventana de gracia (< 30 días desde
  //      canceledAt): mantenemos las plazas para que los empleados puedan
  //      seguir trabajando. La cuenta de farmacia se bloquea aparte.
  //   3) No pagado y fuera de la ventana de gracia: solo queda 1 plaza, el
  //      resto pasa a 'inactive' y los excedentes se marcan 'disabled' al
  //      ejecutar este helper desde el cron de morosidad.
  let allowedActive;
  let blockEmployees = false;

  if (PAID_STATUSES.has(billingStatus)) {
    allowedActive = Math.max(overrideAllowedActive ?? contractedSeats, 1);
  } else if (isWithinGrace(canceledAtMs)) {
    allowedActive = Math.max(overrideAllowedActive ?? contractedSeats, 1);
  } else {
    allowedActive = 1;
    blockEmployees = true;
  }

  const snap = await db.collection('employees').where('companyId', '==', companyId).get();
  if (snap.empty) return;

  const employees = [];
  snap.forEach((doc) => {
    const data = doc.data() || {};
    const createdAt = data.createdAt instanceof admin.firestore.Timestamp ? data.createdAt.toMillis() : 0;
    employees.push({
      ref: doc.ref,
      uid: doc.id,
      createdAt,
      status: data.accountStatus || 'pending',
    });
  });

  const preferDisable = new Set(
      Array.isArray(opts.preferDisableUids) ? opts.preferDisableUids : [],
  );

  // Solo promocionamos/inactivamos los empleados PROMOTABLE (active|inactive|
  // disabled). Los `pending` SÍ ocupan plaza (ver seatPolicy.SEAT_OCCUPYING)
  // pero aún no se mueven entre active/inactive: eso se decide al activar.
  //
  // Prioridad para conservar plaza:
  //   1) No estar en preferDisableUids (la selección del admin manda).
  //   2) Estar activo AHORA (statu quo: una re-evaluación posterior — RTDN,
  //      webhook, cron — no debe recolocar plazas que ya están repartidas).
  //   3) Antigüedad (createdAt asc), como desempate.
  const list = employees
      .filter((e) => PROMOTABLE.has(e.status))
      .sort((a, b) => {
        const aChosen = preferDisable.has(a.uid) ? 1 : 0;
        const bChosen = preferDisable.has(b.uid) ? 1 : 0;
        if (aChosen !== bChosen) return aChosen - bChosen;
        const aActive = a.status === 'active' ? 0 : 1;
        const bActive = b.status === 'active' ? 0 : 1;
        if (aActive !== bActive) return aActive - bActive;
        return a.createdAt - b.createdAt;
      });

  const batch = db.batch();
  list.forEach((emp, index) => {
    let newStatus;
    if (blockEmployees) {
      // Cuenta morosa fuera de gracia: TODOS los empleados (incluso el que
      // ocupa la plaza gratuita) pierden acceso y ven la pantalla de bloqueo.
      newStatus = 'disabled';
    } else if (index < allowedActive) {
      newStatus = 'active';
    } else {
      newStatus = 'inactive';
    }

    if (newStatus !== emp.status) {
      batch.update(emp.ref, {
        accountStatus: newStatus,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

  await batch.commit();

  logger.info('[billingEmployees] updated', {
    companyId,
    billingStatus,
    allowedActive,
    blockEmployees,
    canceledAtMs,
  });
}

module.exports = { updateEmployeesForBillingState, GRACE_DAYS, GRACE_MS };
