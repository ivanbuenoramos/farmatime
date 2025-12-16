// helpers/billingEmployees.js
const { db, admin } = require('../config/firebase');
const logger = require('firebase-functions/logger');

async function updateEmployeesForBillingState(companyId, opts = {}) {
  if (!companyId) return;

  const companySnap = await db.collection('companies').doc(companyId).get();
  if (!companySnap.exists) return;

  const company = companySnap.data() || {};
  const billingStatus = company.billingStatus || 'none';

  const contractedSeats = typeof company.contractedSeats === 'number' ? company.contractedSeats : 1;
  const overrideAllowedActive =
    typeof opts.overrideAllowedActive === 'number' ? opts.overrideAllowedActive : null;

  // allowedActive real
  let allowedActive = 1;

  if (billingStatus === 'active') {
    allowedActive = Math.max(overrideAllowedActive ?? contractedSeats, 1);
  } else {
    // none / past_due / unpaid / canceled -> solo 1
    allowedActive = 1;
  }

  const snap = await db.collection('employees').where('companyId', '==', companyId).get();
  if (snap.empty) return;

  const employees = [];
  snap.forEach((doc) => {
    const data = doc.data() || {};
    const createdAt = data.createdAt instanceof admin.firestore.Timestamp ? data.createdAt.toMillis() : 0;
    employees.push({
      ref: doc.ref,
      createdAt,
      status: data.accountStatus || 'pending',
    });
  });

  const list = employees.filter((e) => e.status !== 'deleted').sort((a, b) => a.createdAt - b.createdAt);

  const batch = db.batch();
  list.forEach((emp, index) => {
    const newStatus = index < allowedActive ? 'active' : 'inactive';
    if (newStatus !== emp.status) {
      batch.update(emp.ref, {
        accountStatus: newStatus,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

  await batch.commit();

  logger.info('[billingEmployees] updated', { companyId, billingStatus, allowedActive });
}

module.exports = { updateEmployeesForBillingState };
