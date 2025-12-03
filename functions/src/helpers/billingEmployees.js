// helpers/billingEmployees.js
const { db, admin } = require('../config/firebase');
const logger = require('firebase-functions/logger');

async function updateEmployeesForBillingState(companyId) {
  if (!companyId) return;

  const companySnap = await db.collection('companies').doc(companyId).get();
  if (!companySnap.exists) {
    logger.warn('[billingEmployees] company not found', { companyId });
    return;
  }

  const company = companySnap.data() || {};
  const billingStatus = company.billingStatus || 'active';
  const contractedSeats =
    typeof company.contractedSeats === 'number' ? company.contractedSeats : 0;

  // Cuántos empleados pueden estar en 'active' (incluyendo el gratuito)
  let allowedActive = 1; // siempre mínimo 1 por el empleado gratuito

  if (billingStatus === 'active') {
    // contractedSeats ya lleva la primera plaza incluida
    allowedActive = Math.max(contractedSeats, 1);
  } else if (billingStatus === 'past_due' || billingStatus === 'unpaid') {
    // solo el más antiguo en active, resto inactive
    allowedActive = 1;
  } else if (billingStatus === 'canceled') {
    // cancelada → el más antiguo sigue active (gratis)
    allowedActive = 1;
  }

  const snap = await db
      .collection('employees')
      .where('companyId', '==', companyId)
      .get();

  if (snap.empty) {
    logger.info('[billingEmployees] no employees for company', { companyId });
    return;
  }

  const employees = [];
  snap.forEach((doc) => {
    const data = doc.data() || {};
    const createdAt =
      data.createdAt instanceof admin.firestore.Timestamp ?
        data.createdAt.toMillis() :
        0;

    employees.push({
      id: doc.id,
      ref: doc.ref,
      createdAt,
      currentStatus: data.accountStatus || 'pending',
    });
  });

  // 🔹 NO tocar empleados deleted:
  const deletedEmployees = employees.filter(
      (e) => e.currentStatus === 'deleted',
  );
  const nonDeletedEmployees = employees.filter(
      (e) => e.currentStatus !== 'deleted',
  );

  // Ordenar por antigüedad (más antiguo primero) SOLO los que no están deleted
  nonDeletedEmployees.sort((a, b) => a.createdAt - b.createdAt);

  const batch = db.batch();

  nonDeletedEmployees.forEach((emp, index) => {
    let newStatus = emp.currentStatus;

    if (billingStatus === 'canceled') {
      if (index === 0) {
        newStatus = 'active';
      } else {
        newStatus = 'disabled'; // si usas 'inactive' en el enum, cámbialo aquí
      }
    } else {
      if (index < allowedActive) {
        newStatus = 'active';
      } else {
        newStatus = 'inactive';
      }
    }

    if (newStatus !== emp.currentStatus) {
      batch.update(emp.ref, {
        accountStatus: newStatus,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

  // 🔹 Los deleted ni se tocan:
  // (si quisieras asegurarte de que se quedan como 'deleted', ni siquiera entras en el bucle)

  await batch.commit();

  logger.info('[billingEmployees] employees updated', {
    companyId,
    billingStatus,
    allowedActive,
    total: employees.length,
    nonDeleted: nonDeletedEmployees.length,
    deleted: deletedEmployees.length,
  });
}

module.exports = { updateEmployeesForBillingState };
