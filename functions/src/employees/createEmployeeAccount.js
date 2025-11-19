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
  const SEAT_STATUSES = ['pending', 'active', 'inactive', 'disabled'];

  async function countActiveEmployees(companyId) {
    // Cuenta todos los empleados que CONSUMEN plaza (no 'deleted')
    const agg = await db
        .collection('employees')
        .where('companyId', '==', companyId)
        .where('accountStatus', 'in', SEAT_STATUSES)
        .count()
        .get();

    return agg.data().count || 0;
  }

  async function getContractedSeats(companyId) {
    const snap = await db.collection('companies').doc(companyId).get();
    if (!snap.exists) throw new HttpsError('not-found', 'Empresa no encontrada');
    const data = snap.data() || {};
    return (
      (typeof data.contractedSeats === 'number' ?
        data.contractedSeats :
        data.purchasedEmployeeSlots) || 0
    );
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
    // Crear usuario en Auth
    const tempPass = Math.random().toString(36).slice(-10) + 'A!';
    createdUser = await admin.auth().createUser({
      email,
      password: tempPass,
      displayName: name,
      emailVerified: false,
      disabled: false,
    });
    logger.info('[createEmployeeAccount] auth user created', {
      uid: createdUser.uid,
      email,
    });

    // Custom claims opcionales
    await admin
        .auth()
        .setCustomUserClaims(createdUser.uid, { companyId, role })
        .catch((e) => {
          logger.warn('[createEmployeeAccount] setCustomUserClaims warn', {
            code: e.code,
            msg: e.message,
          });
        });

    // Rechequeo plazas (por si entre medias se ha creado otro empleado)
    const activeAfter = await countActiveEmployees(companyId);
    logger.info('[createEmployeeAccount] seats/post-auth', {
      maxSeats,
      activeAfter,
    });
    if (activeAfter >= maxSeats) {
      try {
        await admin.auth().deleteUser(createdUser.uid);
      } catch (_) {
        // noop
      }
      throw new HttpsError('failed-precondition', 'Sin plazas disponibles');
    }

    const nowTs = admin.firestore.FieldValue.serverTimestamp();

    // DOC EMPLEADO → alineado con EmployeeModel
    const employeeDoc = {
      uid: createdUser.uid,
      companyId,
      name,
      email,

      // Nuevos campos del modelo
      tempPassword: tempPass,
      photoUrl: null,
      position: null,
      accountStatus: 'pending', // EmployeeAccountStatus.pending
      hireDate: nowTs,

      createdAt: nowTs,
      updatedAt: nowTs,

      hourlyRate: Number(hourlyRate) || 0,
      role, // 'tecnico' | 'auxiliar' | 'farmaceutico' | 'otro'
      roleOther: roleOther || null,
      workdayType: workdayType || null, // 'completa' | 'media' | null
      vacationDaysPer30: Number(vacationDaysPer30) || 2.5,
      personalDaysPerYear: Number(personalDaysPerYear) || 0,
    };

    await db.collection('employees').doc(createdUser.uid).set(employeeDoc);
    logger.info('[createEmployeeAccount] employee doc created', {
      uid: createdUser.uid,
    });

    // Reset link (no crítico)
    let resetLink = null;
    try {
      resetLink = await admin.auth().generatePasswordResetLink(email, {
        url: 'https://tudominio.com/onboarding',
        handleCodeInApp: true,
      });
      logger.info('[createEmployeeAccount] resetLink generated');
    } catch (e) {
      logger.warn('[createEmployeeAccount] resetLink warn', {
        code: e.code,
        msg: e.message,
      });
    }

    logger.info('[createEmployeeAccount] DONE', { uid: createdUser.uid });
    return { uid: createdUser.uid, resetLink };
  } catch (err) {
    const code = err && (err.code || err.errorInfo?.code);
    const msg = err && (err.message || err.errorInfo?.message);

    logger.error('[createEmployeeAccount] ERROR', {
      code,
      msg,
      stack: err?.stack,
    });

    if (createdUser?.uid) {
      try {
        await admin.auth().deleteUser(createdUser.uid);
      } catch (_) {
        // noop
      }
    }

    if (code === 'auth/email-already-exists') {
      throw new HttpsError('already-exists', 'El correo ya está en uso');
    }
    if (code === 'auth/invalid-email') {
      throw new HttpsError('invalid-argument', 'Email inválido');
    }
    if (code === 'auth/operation-not-allowed') {
      throw new HttpsError(
          'failed-precondition',
          'Operación no permitida',
      );
    }
    if (code === 'auth/uid-already-exists') {
      throw new HttpsError('already-exists', 'UID ya existe');
    }
    if (code === 'auth/invalid-password') {
      throw new HttpsError('invalid-argument', 'Password inválida');
    }
    if (code === 'failed-precondition') {
      throw new HttpsError(
          'failed-precondition',
          msg || 'Fallo de precondición',
      );
    }

    throw new HttpsError('internal', msg || 'Error interno');
  }
});
