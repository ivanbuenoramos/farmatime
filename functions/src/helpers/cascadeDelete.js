// cascadeDelete.js
// Borrado en cascada de datos de empresa y empleados (GDPR / derecho al olvido).
//
// Firestore no borra subcolecciones al borrar el documento padre, así que hay
// que recorrerlas explícitamente. Borramos por lotes (batch de 400) para no
// exceder el límite de 500 operaciones por commit.
const { db, admin } = require('../config/firebase');
const logger = require('firebase-functions/logger');

const BATCH_LIMIT = 400;

// Borra todos los documentos de una query (paginando) y, opcionalmente, una
// subcolección de cada uno. Devuelve el número de documentos borrados.
async function deleteQuery(query, { subcollections = [] } = {}) {
  let deleted = 0;
  // eslint-disable-next-line no-constant-condition
  while (true) {
    const snap = await query.limit(BATCH_LIMIT).get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      for (const sub of subcollections) {
        await deleteCollection(doc.ref.collection(sub));
      }
    }

    const batch = db.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    deleted += snap.size;

    if (snap.size < BATCH_LIMIT) break;
  }
  return deleted;
}

async function deleteCollection(colRef) {
  return deleteQuery(colRef);
}

// Borra los ficheros de Storage bajo un prefijo (carpeta lógica).
async function deleteStoragePrefix(prefix) {
  try {
    const bucket = admin.storage().bucket();
    await bucket.deleteFiles({ prefix });
  } catch (e) {
    logger.warn('[cascadeDelete] storage prefix warn', { prefix, msg: e?.message });
  }
}

// Borra el usuario de Firebase Auth por uid (silencioso si no existe).
async function deleteAuthUser(uid) {
  if (!uid) return;
  try {
    await admin.auth().deleteUser(uid);
  } catch (e) {
    if (e?.code !== 'auth/user-not-found') {
      logger.warn('[cascadeDelete] auth delete warn', { uid, msg: e?.message });
    }
  }
}

// Borra TODO lo asociado a un empleado: doc, fichajes (+auditLog), reportes,
// reglas/overrides de horario, ausencias, tokens FCM, Storage y Auth. También
// lo retira de las conversaciones de grupo.
async function deleteEmployeeData(employeeUid, { companyId = null } = {}) {
  if (!employeeUid) return;

  await deleteQuery(
      db.collection('clockRecords').where('employeeId', '==', employeeUid),
      { subcollections: ['auditLog'] },
  );
  await deleteQuery(db.collection('clockReports').where('employeeId', '==', employeeUid));
  await deleteQuery(db.collection('employee_schedule_rules').where('employeeId', '==', employeeUid));
  await deleteQuery(db.collection('employee_schedule_months').where('employeeId', '==', employeeUid));
  await deleteQuery(db.collection('time_off_requests').where('employeeId', '==', employeeUid));

  // Tokens FCM del usuario: user_fcm_tokens/{uid}/tokens/*
  await deleteCollection(db.collection('user_fcm_tokens').doc(employeeUid).collection('tokens'));
  await db.collection('user_fcm_tokens').doc(employeeUid).delete().catch(() => {});

  // Subcolección privada (credenciales temporales) del empleado.
  await deleteCollection(db.collection('employees').doc(employeeUid).collection('private'));

  // Retirarlo de conversaciones de grupo y borrar sus DMs.
  await removeUserFromConversations(employeeUid);

  // Storage del empleado (fotos).
  await deleteStoragePrefix(`employees/${employeeUid}`);
  await deleteStoragePrefix(`companies/${employeeUid}`);

  // Doc del empleado y cuenta Auth.
  await db.collection('employees').doc(employeeUid).delete().catch(() => {});
  await deleteAuthUser(employeeUid);

  logger.info('[cascadeDelete] employee purged', { employeeUid, companyId });
}

// Retira a un usuario de los grupos y borra (con mensajes) los DMs en los que
// estuviera. Mantiene los grupos vivos para el resto de miembros.
async function removeUserFromConversations(uid) {
  const snap = await db
      .collection('conversations')
      .where('memberIds', 'array-contains', uid)
      .get();

  for (const conv of snap.docs) {
    const data = conv.data() || {};
    if (data.isGroup) {
      // Lo quitamos del grupo conservando la conversación.
      await conv.ref.update({
        memberIds: admin.firestore.FieldValue.arrayRemove(uid),
        [`unreadCounts.${uid}`]: admin.firestore.FieldValue.delete(),
      }).catch(() => {});
    } else {
      // DM: se borra junto con sus mensajes.
      await deleteCollection(conv.ref.collection('messages'));
      await conv.ref.delete().catch(() => {});
    }
  }
}

// Borra TODA la empresa y sus empleados.
async function deleteCompanyData(companyId) {
  if (!companyId) return;

  // 1) Empleados (cada uno con su cascada). La empresa = uid de empresa, no es
  // empleado, así que se trata aparte.
  const empSnap = await db
      .collection('employees')
      .where('companyId', '==', companyId)
      .get();
  for (const emp of empSnap.docs) {
    const uid = emp.data()?.uid || emp.id;
    await deleteEmployeeData(uid, { companyId });
  }

  // 2) Datos a nivel de empresa que pudieran no estar ligados a un empleado.
  await deleteQuery(
      db.collection('clockRecords').where('companyId', '==', companyId),
      { subcollections: ['auditLog'] },
  );
  await deleteQuery(db.collection('clockReports').where('companyId', '==', companyId));
  await deleteQuery(db.collection('company_shift_templates').where('companyId', '==', companyId));
  await deleteQuery(db.collection('employee_schedule_rules').where('companyId', '==', companyId));
  await deleteQuery(db.collection('employee_schedule_months').where('companyId', '==', companyId));
  await deleteQuery(db.collection('time_off_requests').where('companyId', '==', companyId));

  // 3) Conversaciones de la empresa (la empresa participa como un miembro más).
  await removeUserFromConversations(companyId);
  await deleteQuery(
      db.collection('conversations').where('companyId', '==', companyId),
      { subcollections: ['messages'] },
  );

  // 4) Tokens FCM, suscripción anidada, Storage, doc y Auth de la empresa.
  await deleteCollection(db.collection('user_fcm_tokens').doc(companyId).collection('tokens'));
  await db.collection('user_fcm_tokens').doc(companyId).delete().catch(() => {});
  await deleteCollection(db.collection('companies').doc(companyId).collection('subscription'));
  await deleteStoragePrefix(`companies/${companyId}`);
  await db.collection('companies').doc(companyId).delete().catch(() => {});
  await deleteAuthUser(companyId);

  logger.info('[cascadeDelete] company purged', { companyId, employees: empSnap.size });
}

module.exports = {
  deleteEmployeeData,
  deleteCompanyData,
  removeUserFromConversations,
  deleteCollection,
};
