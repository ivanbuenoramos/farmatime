// functions/src/notifications/names.js
//
// Helpers para resolver nombres legibles de empleados/empresas en las
// notificaciones (evita textos genéricos como "El empleado").

const { db } = require('../config/firebase');

/**
 * Nombre del empleado por su id. Fallback 'Un empleado' si no se encuentra.
 * @param {string} employeeId
 * @return {Promise<string>}
 */
async function employeeName(employeeId) {
  if (!employeeId) return 'Un empleado';
  try {
    const snap = await db.collection('employees').doc(employeeId).get();
    const name = snap.exists ? snap.get('name') : null;
    return name && String(name).trim() ? String(name) : 'Un empleado';
  } catch (_) {
    return 'Un empleado';
  }
}

module.exports = { employeeName };
