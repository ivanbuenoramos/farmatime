const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { db, admin } = require('../config/firebase');
const { assertCompanyAccount } = require('../helpers/assertions');
const logger = require('firebase-functions/logger');

exports.createEmployeeAccount = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Login requerido');
  const callerUid = request.auth.uid;

  const {
    companyId,
    name,
    email,
    hourlyRate = 0,
    role = 'tecnico',
    roleOther = null,
    workdayType = null,
    vacationDaysPer30 = 2.5,
    personalDaysPerYear = 0,
  } = request.data || {};

  // Validaciones
  if (!companyId || typeof companyId !== 'string') {
    throw new HttpsError('invalid-argument', 'companyId inválido');
  }
  if (!name || typeof name !== 'string') {
    throw new HttpsError('invalid-argument', 'name inválido');
  }
  if (!email || typeof email !== 'string') {
    throw new HttpsError('invalid-argument', 'email inválido');
  }

  // Autorización
  await assertCompanyAccount(callerUid, companyId);

  // Helpers locales
  async function countActiveEmployees(companyId) {
    const agg = await db
        .collection('employees')
        .where('companyId', '==', companyId)
        .where('isActive', '==', true)
        .count()
        .get();
    return agg.data().count || 0;
  }
  async function getContractedSeats(companyId) {
    const snap = await db.collection('companies').doc(companyId).get();
    if (!snap.exists) throw new HttpsError('not-found', 'Empresa no encontrada');
    const data = snap.data() || {};
    return (typeof data.contractedSeats === 'number' ? data.contractedSeats : data.purchasedEmployeeSlots) || 0;
  }

  logger.info('[createEmployeeAccount] START', { companyId, email, role });

  // Chequeo plazas (pre)
  const maxSeats = await getContractedSeats(companyId);
  const activeBefore = await countActiveEmployees(companyId);
  logger.info('[createEmployeeAccount] seats/pre', { maxSeats, activeBefore });
  if (activeBefore >= maxSeats) {
    throw new HttpsError('failed-precondition', 'Sin plazas disponibles');
  }

  let createdUser = null;
  try {
    // Crear usuario
    const tempPass = Math.random().toString(36).slice(-10) + 'A!';
    createdUser = await admin.auth().createUser({
      email,
      password: tempPass,
      displayName: name,
      emailVerified: false,
      disabled: false,
    });
    logger.info('[createEmployeeAccount] auth user created', { uid: createdUser.uid, email });

    // Custom claims opcionales
    await admin.auth().setCustomUserClaims(createdUser.uid, { companyId, role }).catch((e) => {
      logger.warn('[createEmployeeAccount] setCustomUserClaims warn', { code: e.code, msg: e.message });
    });

    // Rechequeo plazas
    const activeAfter = await countActiveEmployees(companyId);
    logger.info('[createEmployeeAccount] seats/post-auth', { maxSeats, activeAfter });
    if (activeAfter >= maxSeats) {
      try {
        await admin.auth().deleteUser(createdUser.uid);
      } catch (_) {
        // noop
      }
      throw new HttpsError('failed-precondition', 'Sin plazas disponibles');
    }

    // Crear doc empleado
    const employeeDoc = {
      uid: createdUser.uid,
      companyId,
      name,
      email,
      tempPassword: tempPass,
      isActive: true,
      hourlyRate: Number(hourlyRate) || 0,
      role,
      roleOther: roleOther || null,
      workdayType: workdayType || null,
      vacationDaysPer30: Number(vacationDaysPer30) || 2.5,
      personalDaysPerYear: Number(personalDaysPerYear) || 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.collection('employees').doc(createdUser.uid).set(employeeDoc);
    logger.info('[createEmployeeAccount] employee doc created', { uid: createdUser.uid });

    // Reset link (no crítico)
    let resetLink = null;
    try {
      // ⚠️ Asegúrate de que la URL esté en Auth > Dominios autorizados.
      // Si no, quita el objeto de settings y deja el valor por defecto:
      // resetLink = await admin.auth().generatePasswordResetLink(email);
      resetLink = await admin.auth().generatePasswordResetLink(email, {
        url: 'https://tudominio.com/onboarding', // <- autoriza este dominio o usa tu *.web.app / *.firebaseapp.com
        handleCodeInApp: true,
      });
      logger.info('[createEmployeeAccount] resetLink generated');
    } catch (e) {
      logger.warn('[createEmployeeAccount] resetLink warn', { code: e.code, msg: e.message });
      // No fallamos la función por esto
    }

    logger.info('[createEmployeeAccount] DONE', { uid: createdUser.uid });
    return { uid: createdUser.uid, resetLink };
  } catch (err) {
    // Mapeo de errores comunes para evitar "INTERNAL" genérico
    const code = err && (err.code || err.errorInfo?.code);
    const msg = err && (err.message || err.errorInfo?.message);

    logger.error('[createEmployeeAccount] ERROR', { code, msg, stack: err?.stack });

    // Limpieza si se creó el usuario
    if (createdUser?.uid) {
      try {
        await admin.auth().deleteUser(createdUser.uid);
      } catch (_) {
        // noop
      }
    }

    // Mapear errores típicos de Auth Admin
    if (code === 'auth/email-already-exists') {
      throw new HttpsError('already-exists', 'El correo ya está en uso');
    }
    if (code === 'auth/invalid-email') {
      throw new HttpsError('invalid-argument', 'Email inválido');
    }
    if (code === 'auth/operation-not-allowed') {
      throw new HttpsError('failed-precondition', 'Operación no permitida');
    }
    if (code === 'auth/uid-already-exists') {
      throw new HttpsError('already-exists', 'UID ya existe');
    }
    if (code === 'auth/invalid-password') {
      throw new HttpsError('invalid-argument', 'Password inválida');
    }
    if (code === 'failed-precondition') {
      // por si lanzamos nosotros mismos antes
      throw new HttpsError('failed-precondition', msg || 'Fallo de precondición');
    }

    throw new HttpsError('internal', msg || 'Error interno');
  }
});
