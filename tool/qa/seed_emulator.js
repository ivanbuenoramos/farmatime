#!/usr/bin/env node
/* eslint-disable */
/**
 * Semillas deterministas para el Firebase Emulator Suite (QA Farmatime).
 *
 * Uso (con los emuladores arrancados):
 *   node tool/qa/seed_emulator.js            # resetea Auth+Firestore y siembra
 *   node tool/qa/seed_emulator.js --no-reset # solo siembra (idempotente: set())
 *
 * Nunca apunta a producción: exige las variables *_EMULATOR_HOST y, si no
 * están, las fija a 127.0.0.1. Reutiliza firebase-admin de functions/node_modules.
 */
const path = require('path');
const http = require('http');

process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || 'farmatime-app';
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
process.env.FIREBASE_STORAGE_EMULATOR_HOST = process.env.FIREBASE_STORAGE_EMULATOR_HOST || '127.0.0.1:9199';

const admin = require(path.join(__dirname, '..', '..', 'functions', 'node_modules', 'firebase-admin'));
admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT });
const db = admin.firestore();
const { Timestamp } = admin.firestore;

const PROJECT = process.env.GCLOUD_PROJECT;
const PASSWORD = 'Password123!';

// --- Datos canónicos (los usan también las pruebas de integración) ---
const SEED = {
  password: PASSWORD,
  companyPaid: { uid: 'qa-company-paid', email: 'farmacia.qa@farmatime.test', legalName: 'Farmacia QA Central' },
  companyFree: { uid: 'qa-company-free', email: 'farmacia.gratis@farmatime.test', legalName: 'Farmacia QA Gratis' },
  employees: {
    ana: { uid: 'qa-emp-ana', email: 'ana.qa@farmatime.test', name: 'Ana Pérez', companyId: 'qa-company-paid', accountStatus: 'active', role: 'farmaceutico', avatarColor: 0xFFB5D8F6 },
    luis: { uid: 'qa-emp-luis', email: 'luis.qa@farmatime.test', name: 'Luis Gómez', companyId: 'qa-company-paid', accountStatus: 'active', role: 'auxiliar', avatarColor: 0xFFF6D5B5 },
    marta: { uid: 'qa-emp-marta', email: 'marta.qa@farmatime.test', name: 'Marta Ruiz', companyId: 'qa-company-paid', accountStatus: 'pending', role: 'tecnico', avatarColor: 0xFFD5F6B5, tempPassword: 'temp1234A!' },
    borrado: { uid: 'qa-emp-borrado', email: 'borrado.qa@farmatime.test', name: 'Empleado Borrado', companyId: 'qa-company-paid', accountStatus: 'deleted', role: 'tecnico', avatarColor: 0xFFEEEEEE },
    solo: { uid: 'qa-emp-solo', email: 'solo.qa@farmatime.test', name: 'Sole Único', companyId: 'qa-company-free', accountStatus: 'active', role: 'tecnico', avatarColor: 0xFFF6B5E8 },
  },
};

function del(hostPort, pathname) {
  const [host, port] = hostPort.split(':');
  return new Promise((resolve, reject) => {
    const req = http.request({ host, port, path: pathname, method: 'DELETE' }, (res) => {
      res.resume();
      res.on('end', () => resolve(res.statusCode));
    });
    req.on('error', reject);
    req.end();
  });
}

async function reset() {
  const fs = await del(process.env.FIRESTORE_EMULATOR_HOST, `/emulator/v1/projects/${PROJECT}/databases/(default)/documents`);
  const au = await del(process.env.FIREBASE_AUTH_EMULATOR_HOST, `/emulator/v1/projects/${PROJECT}/accounts`);
  console.log(`reset: firestore=${fs} auth=${au}`);
}

async function ensureUser({ uid, email, password, displayName, emailVerified = true, claims }) {
  try { await admin.auth().deleteUser(uid); } catch (_) { /* no existía */ }
  await admin.auth().createUser({ uid, email, password, displayName, emailVerified, disabled: false });
  if (claims) await admin.auth().setCustomUserClaims(uid, claims);
}

function companyDoc(c, extra) {
  const now = Timestamp.now();
  return {
    id: c.uid, email: c.email, logoUrl: null, legalName: c.legalName,
    vatNumber: 'B12345678',
    address: { address: 'Calle Mayor 1', city: 'Madrid', state: 'Madrid', country: 'España', zipCode: '28001' },
    phoneNumber: { countryCode: '+34', number: '600000000', lastUpdate: null },
    authMethod: 'emailPassword', verifiedEmail: true, verifiedPhone: false,
    createdAt: now, updatedAt: now,
    ...extra,
  };
}

function employeeDoc(e) {
  const now = Timestamp.now();
  const hire = Timestamp.fromDate(new Date(Date.now() - 400 * 86400000)); // >1 año de antigüedad
  const doc = {
    uid: e.uid, email: e.email, name: e.name, companyId: e.companyId,
    photoUrl: null, position: null, accountStatus: e.accountStatus,
    hireDate: hire, createdAt: now, updatedAt: now,
    hourlyRate: 12.5, role: e.role, roleOther: null, workdayType: 'completa',
    vacationDaysPer30: 2.5, personalDaysPerYear: 3,
    avatarColor: e.avatarColor,
    hasTempPassword: !!e.tempPassword,
  };
  return doc;
}

async function seed() {
  const b = db.batch();
  // Empresas
  await ensureUser({ uid: SEED.companyPaid.uid, email: SEED.companyPaid.email, password: PASSWORD, displayName: SEED.companyPaid.legalName });
  await ensureUser({ uid: SEED.companyFree.uid, email: SEED.companyFree.email, password: PASSWORD, displayName: SEED.companyFree.legalName });
  const periodEnd = Timestamp.fromDate(new Date(Date.now() + 20 * 86400000));
  b.set(db.doc(`companies/${SEED.companyPaid.uid}`), companyDoc(SEED.companyPaid, {
    contractedSeats: 5, billingStatus: 'active', currentPeriodEnd: periodEnd,
    subscription: { status: 'active', store: 'apple', productId: 'plan_5_employees', autoRenewing: true, currentPeriodEnd: periodEnd, canceledAt: null },
  }));
  b.set(db.doc(`companies/${SEED.companyFree.uid}`), companyDoc(SEED.companyFree, { contractedSeats: 1, billingStatus: 'none' }));

  // Empleados
  for (const e of Object.values(SEED.employees)) {
    await ensureUser({ uid: e.uid, email: e.email, password: e.tempPassword || PASSWORD, displayName: e.name, emailVerified: false, claims: { companyId: e.companyId, role: e.role } });
    b.set(db.doc(`employees/${e.uid}`), employeeDoc(e));
    if (e.tempPassword) {
      b.set(db.doc(`employees/${e.uid}/private/credentials`), { tempPassword: e.tempPassword, createdAt: Timestamp.now() });
    }
  }

  // Plantillas de turno (empresa de pago). Forma = ShiftTemplate.toJson():
  // start/end 'HHmm', breakMinutes?, color?, active.
  b.set(db.doc('company_shift_templates/qa-tpl-manana'), {
    companyId: SEED.companyPaid.uid, name: 'Mañana', start: '0900', end: '1400', color: 0xFF4CAF50, active: true,
  });
  b.set(db.doc('company_shift_templates/qa-tpl-tarde'), {
    companyId: SEED.companyPaid.uid, name: 'Tarde', start: '1600', end: '2030', breakMinutes: 15, color: 0xFF2196F3, active: true,
  });
  b.set(db.doc('company_shift_templates/qa-tpl-noche'), {
    companyId: SEED.companyPaid.uid, name: 'Noche', start: '2200', end: '0600', color: 0xFF9C27B0, active: true,
  });

  await b.commit();

  // --big: historial masivo de fichajes para Luis (pruebas de rendimiento/listas
  // extensas). N registros cerrados de 8 h repartidos hacia atrás, 1 por día.
  if (process.argv.includes('--big')) {
    const n = Number((process.argv.find((a) => a.startsWith('--big=')) || '--big=3000').split('=')[1]) || 3000;
    let batch = db.batch(); let count = 0;
    for (let i = 1; i <= n; i++) {
      const day = new Date(Date.now() - i * 86400000);
      const cin = new Date(day); cin.setHours(9, 0, 0, 0);
      const cout = new Date(day); cout.setHours(17, 0, 0, 0);
      const id = `qa-big-luis-${i}`;
      batch.set(db.doc(`clockRecords/${id}`), {
        id, employeeId: SEED.employees.luis.uid, companyId: SEED.companyPaid.uid,
        clockIn: Timestamp.fromDate(cin), clockOut: Timestamp.fromDate(cout),
        clockInLat: 40.4168, clockInLng: -3.7038, clockOutLat: 40.4168, clockOutLng: -3.7038,
        isEdited: false, editedBy: null, editedAt: null, editReason: null, editedFields: [],
        createdAt: Timestamp.fromDate(cin), updatedAt: Timestamp.fromDate(cout),
      });
      count++;
      if (count % 400 === 0) { await batch.commit(); batch = db.batch(); }
    }
    await batch.commit();
    console.log(`seed: +${n} fichajes historicos para Luis (--big)`);
  }
  console.log('seed: ok');
  console.log(JSON.stringify(SEED, null, 2));
}

(async () => {
  if (!process.argv.includes('--no-reset')) await reset();
  await seed();
  process.exit(0);
})().catch((e) => { console.error('seed FAILED', e); process.exit(1); });
