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

  // Cuántos empleados pueden estar en 'active'
  let allowedActive = 1; // siempre mínimo 1 por el empleado gratuito

  if (billingStatus === 'active') {
    // Aquí contractedSeats ya lleva la primera plaza incluida
    allowedActive = Math.max(contractedSeats, 1);
  } else if (billingStatus === 'past_due' || billingStatus === 'unpaid') {
    allowedActive = 1; // solo el más antiguo
  } else if (billingStatus === 'canceled') {
    allowedActive = 0; // todos disabled
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
    const createdAt = data.createdAt instanceof admin.firestore.Timestamp ?
      data.createdAt.toMillis() :
      0;

    employees.push({
      id: doc.id,
      ref: doc.ref,
      createdAt,
      currentStatus: data.accountStatus || 'pending',
    });
  });

  // Ordenar por antigüedad (más antiguo primero)
  employees.sort((a, b) => a.createdAt - b.createdAt);

  const batch = db.batch();

  employees.forEach((emp, index) => {
    let newStatus = emp.currentStatus;

    if (billingStatus === 'canceled') {
      // Cancelada -> todos disabled
      newStatus = 'disabled';
    } else {
      // active / past_due / unpaid / lo que sea
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

  await batch.commit();

  logger.info('[billingEmployees] employees updated', {
    companyId,
    billingStatus,
    allowedActive,
    total: employees.length,
  });
}

module.exports = { updateEmployeesForBillingState };
