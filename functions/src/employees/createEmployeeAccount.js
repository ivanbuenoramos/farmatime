const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { db, admin } = require('../config/firebase');
const { assertCompanyAccount } = require('../helpers/assertions');
const { SEAT_OCCUPYING } = require('../helpers/seatPolicy');
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

  // Estados que CONSUMEN plaza (ver helpers/seatPolicy.js).
  const SEAT_STATUSES = Array.from(SEAT_OCCUPYING);

  logger.info('[createEmployeeAccount] START', { companyId, email, role });

  // 1) Reserva atómica de plaza.
  //
  // No basta con contar antes y después (dos peticiones concurrentes podían
  // colarse en la ventana entre conteo y creación). Hacemos una transacción que
  // (a) lee las plazas contratadas de la empresa, (b) cuenta los empleados que
  // ocupan plaza y (c) crea el doc del empleado SOLO si queda hueco. Como la
  // creación del doc forma parte de la misma transacción, dos altas simultáneas
  // se serializan: la segunda relee el conteo ya incrementado por la primera.
  //
  // El UID definitivo lo asigna Auth, pero necesitamos reservar la plaza antes
  // de crear el usuario. Usamos un id de documento autogenerado como reserva y,
  // tras crear el Auth user, migramos el doc al UID real.
  const reservationRef = db.collection('employees').doc();
  const nowTs = admin.firestore.FieldValue.serverTimestamp();

  // baseDoc se usa tanto para el doc de RESERVA (temporal, sin tempPassword)
  // como para el doc FINAL bajo el UID de Auth (al que añadimos tempPassword).
  // El doc temporal lleva _pendingReservation=true para que los triggers
  // onDocumentCreated (sendEmployeeWelcome, onSeatsNearLimit, etc.) lo ignoren
  // y no se disparen dos veces ni con datos incompletos.
  const baseDoc = {
    companyId,
    name,
    email,
    photoUrl: null,
    position: null,
    accountStatus: 'pending', // EmployeeAccountStatus.pending — ocupa plaza
    hireDate: nowTs,
    createdAt: nowTs,
    updatedAt: nowTs,
    hourlyRate: Number(hourlyRate) || 0,
    role,
    roleOther: roleOther || null,
    workdayType: workdayType || null,
    vacationDaysPer30: Number(vacationDaysPer30) || 2.5,
    personalDaysPerYear: Number(personalDaysPerYear) || 0,
  };

  const reservationDoc = { ...baseDoc, _pendingReservation: true };

  await db.runTransaction(async (txn) => {
    const companySnap = await txn.get(db.collection('companies').doc(companyId));
    if (!companySnap.exists) {
      throw new HttpsError('not-found', 'Empresa no encontrada');
    }
    const companyData = companySnap.data() || {};
    const maxSeats =
      (typeof companyData.contractedSeats === 'number' ?
        companyData.contractedSeats :
        companyData.purchasedEmployeeSlots) || 0;

    const occupyingSnap = await txn.get(
        db.collection('employees')
            .where('companyId', '==', companyId)
            .where('accountStatus', 'in', SEAT_STATUSES),
    );

    logger.info('[createEmployeeAccount] seats/txn', {
      maxSeats,
      occupying: occupyingSnap.size,
    });

    if (occupyingSnap.size >= maxSeats) {
      throw new HttpsError('failed-precondition', 'Sin plazas disponibles');
    }

    txn.set(reservationRef, reservationDoc);
  });

  let createdUser = null;

  try {
    // 2) Crear usuario en Auth con la plaza ya reservada.
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

    // 3) Migrar la reserva al UID real de Auth (el modelo indexa por uid) y
    // eliminar el doc temporal, en un batch atómico.
    //
    // SEGURIDAD (GDPR): NO escribimos `tempPassword` en el doc principal de
    // `employees/{uid}` — sería legible por todos los compañeros (la regla de
    // read de employees permite a la empresa entera leerse para chat/calendario,
    // y Firestore no soporta read-rules a nivel de campo). En su lugar, lo
    // guardamos en la subcolección privada `employees/{uid}/private/credentials`,
    // protegida por reglas que solo permiten lectura al propio uid.
    const finalRef = db.collection('employees').doc(createdUser.uid);
    const privateRef = finalRef.collection('private').doc('credentials');
    const batch = db.batch();
    batch.set(finalRef, {
      ...baseDoc,
      uid: createdUser.uid,
      // Flag informativo: el cliente sabe que debe forzar set_password sin ver
      // la contraseña en sí.
      hasTempPassword: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    batch.set(privateRef, {
      tempPassword: tempPass,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    batch.delete(reservationRef);
    await batch.commit();
    logger.info('[createEmployeeAccount] employee doc created', {
      uid: createdUser.uid,
    });

    // 4) Enviar el email de bienvenida con la tempPassword DIRECTAMENTE desde
    // aquí (antes lo hacía el trigger sendEmployeeWelcome al leer tempPassword
    // del doc principal; ahora ese campo ya no está en el doc).
    try {
      const now = new Date()
          .toLocaleString('es-ES', { timeZone: 'Europe/Madrid' });
      const subject = 'Bienvenido a FarmaTime';
      const html = `
        <p>Hola${name ? ' ' + name : ''},</p>
        <p>Tu cuenta de empleado en <b>FarmaTime</b> ha sido creada correctamente.</p>
        <p>Estos son tus datos de acceso:</p>
        <ul>
          <li><b>Email:</b> ${email}</li>
          <li><b>Contraseña temporal:</b> ${tempPass}</li>
        </ul>
        <p>Por seguridad, cambia la contraseña al iniciar sesión.</p>
        <br/>
        <p>Fecha de creación: ${now}</p>
        <p>— Equipo FarmaTime</p>
      `;
      const text =
        `Hola${name ? ' ' + name : ''},\n` +
        `Tu cuenta de empleado en FarmaTime ha sido creada.\n` +
        `Email: ${email}\n` +
        `Contraseña temporal: ${tempPass}\n` +
        `Por seguridad, cambia la contraseña al iniciar sesión.\n` +
        `Fecha: ${now}\n`;
      await db.collection('mail').add({
        to: [email],
        from: 'no-reply@farmatime.net',
        message: { subject, html, text },
      });
      logger.info('[createEmployeeAccount] welcome email queued', { email });
    } catch (e) {
      logger.warn('[createEmployeeAccount] welcome email warn', {
        msg: e?.message,
      });
    }

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

    // Rollback: liberamos la plaza reservada y el Auth user si se llegó a crear.
    try {
      await reservationRef.delete();
    } catch (_) {
      // noop (puede que ya se migrara al UID real)
    }
    if (createdUser?.uid) {
      try {
        await admin.auth().deleteUser(createdUser.uid);
      } catch (_) {
        // noop
      }
      try {
        await db.collection('employees').doc(createdUser.uid).delete();
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
