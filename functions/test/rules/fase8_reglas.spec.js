'use strict';

/**
 * Fase 8 (corrección QA) — reglas de Firestore del flujo de fichaje del
 * empleado, consultas de la empresa, estado de cuenta y uid inmutable.
 *
 * Cubre:
 *   - CAND-010 / FND-serialization-null (clockRecords): el empleado puede
 *     cerrar un fichaje abierto que la empresa editó, pero solo tocando
 *     clockOut/clockOutLat/clockOutLng/updatedAt y nunca uno ya cerrado.
 *   - CAND-011: la empresa lista los fichajes de un empleado filtrando por
 *     employeeId + companyId.
 *   - FND-firestore-rules-queries (accountStatus): empleados inactive/disabled
 *     no escriben (fichajes, ausencias, chat, meses de horario); la lectura y
 *     la activación pending → active siguen funcionando.
 *   - employees.uid no puede cambiarse en update (ni empresa ni empleado).
 *
 * Requiere el emulador de Firestore en 127.0.0.1:8080 (`npm test` desde functions/).
 */

const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  collection,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  query,
  where,
  orderBy,
  Timestamp,
  setLogLevel,
} = require('firebase/firestore');

setLogLevel('silent');

const PROJECT_ID = 'farmatime-rules-fase8';
const RULES_PATH = path.resolve(__dirname, '..', '..', '..', 'firestore.rules');
const EMULATOR_HOST = '127.0.0.1';
const EMULATOR_PORT = 8080;

// ---------- Actores ----------
const COMPANY_A = 'companyA';
const COMPANY_B = 'companyB';
const ALICE = 'alice'; // activa, companyA
const INES = 'ines'; // inactive (sin plaza), companyA
const DANI = 'dani'; // disabled (impago), companyA
const PEDRO = 'pedro'; // pending (contraseña temporal), companyA
const CAROL = 'carol'; // activa, companyB

// ---------- Docs sembrados ----------
const CLOCK_A_OPEN = 'clockAliceOpen'; // abierto, sin editar
const CLOCK_A_EDITED_OPEN = 'clockAliceEditedOpen'; // abierto, editado por la empresa
const CLOCK_A_CLOSED = 'clockAliceClosed'; // cerrado
const CLOCK_I_OPEN = 'clockInesOpen';
const CLOCK_D_OPEN = 'clockDaniOpen';
const REQ_ALICE = 'reqAlice';
const REQ_INES = 'reqInes';
const REQ_DANI = 'reqDani';
const GROUP_A = 'groupA';
const MONTH = '2026-11';
const MONTH_NEXT = '2026-12';

const monthId = (companyId, employeeId, month) => `${companyId}__${employeeId}__${month}`;

const T_ORIGINAL_IN = Timestamp.fromDate(new Date('2026-10-01T08:05:00Z'));
const T_EDITED_IN = Timestamp.fromDate(new Date('2026-10-01T08:00:00Z'));
const T_EDITED_AT = Timestamp.fromDate(new Date('2026-10-01T10:00:00Z'));
const T_OUT = Timestamp.fromDate(new Date('2026-10-01T16:00:00Z'));
const T_OUT_2 = Timestamp.fromDate(new Date('2026-10-01T17:00:00Z'));
const T_CREATED = T_ORIGINAL_IN;

function companyDoc(id) {
  return {
    id,
    email: `${id}@farmatime.test`,
    legalName: `Farmacia ${id}`,
    contractedSeats: 1,
    billingStatus: 'none',
    createdAt: T_CREATED,
    updatedAt: T_CREATED,
  };
}

function employeeDoc(uid, companyId, extra = {}) {
  return {
    uid,
    companyId,
    email: `${uid}@farmatime.test`,
    name: uid,
    photoUrl: null,
    hourlyRate: 12.5,
    role: 'pharmacist',
    roleOther: null,
    workdayType: 'full',
    vacationDaysPer30: 2.5,
    personalDaysPerYear: 3,
    position: 'Farmacéutico',
    accountStatus: 'active',
    hasTempPassword: false,
    hireDate: T_CREATED,
    createdAt: T_CREATED,
    updatedAt: T_CREATED,
    ...extra,
  };
}

function clockDoc(id, employeeId, companyId, extra = {}) {
  return {
    id,
    employeeId,
    companyId,
    clockIn: T_ORIGINAL_IN,
    clockOut: null,
    clockInLat: 40.4,
    clockInLng: -3.7,
    clockOutLat: null,
    clockOutLng: null,
    isEdited: false,
    editedBy: null,
    editedAt: null,
    editReason: null,
    editedFields: [],
    createdAt: T_CREATED,
    updatedAt: T_CREATED,
    ...extra,
  };
}

// Fichaje abierto que la empresa corrigió (entrada 08:05 → 08:00) sin cerrar.
function editedOpenClockDoc(id, employeeId, companyId) {
  return clockDoc(id, employeeId, companyId, {
    clockIn: T_EDITED_IN,
    isEdited: true,
    editedBy: 'company',
    editedAt: T_EDITED_AT,
    editReason: 'Llegó a las 8',
    editedFields: ['clockIn'],
    updatedAt: T_EDITED_AT,
  });
}

// Lo que escribe el cliente del empleado al cerrar (update parcial).
function closePayload(ts = T_OUT) {
  return {
    clockOut: ts,
    clockOutLat: 40.41,
    clockOutLng: -3.71,
    updatedAt: Timestamp.now(),
  };
}

function timeOffDoc(companyId, employeeId, status = 'requested') {
  return {
    companyId,
    employeeId,
    type: 'vacation',
    status,
    dates: ['2026-11-02', '2026-11-03'],
    proposedDates: [],
    createdAt: T_CREATED,
    updatedAt: T_CREATED,
  };
}

function conversationDoc(companyId, memberIds, extra = {}) {
  return {
    companyId,
    isGroup: false,
    title: null,
    memberIds,
    lastMessageText: null,
    lastMessageSenderId: null,
    lastMessageAt: null,
    unreadCounts: Object.fromEntries(memberIds.map((m) => [m, 0])),
    updatedAt: T_CREATED,
    ...extra,
  };
}

function messageDoc(conversationId, senderId) {
  return { conversationId, senderId, text: 'Hola', createdAt: T_CREATED };
}

function monthDoc(companyId, employeeId, month) {
  return {
    companyId,
    employeeId,
    month,
    entries: { [`${month}-05`]: { type: 'work', templateId: 'tpl' } },
    createdAt: T_CREATED,
    updatedAt: T_CREATED,
  };
}

// ---------- Entorno ----------
let testEnv;
const dbCache = new Map();

function asUser(uid) {
  if (!dbCache.has(uid)) {
    dbCache.set(uid, testEnv.authenticatedContext(uid).firestore());
  }
  return dbCache.get(uid);
}

async function seedBase() {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await Promise.all([
      setDoc(doc(db, 'companies', COMPANY_A), companyDoc(COMPANY_A)),
      setDoc(doc(db, 'companies', COMPANY_B), companyDoc(COMPANY_B)),
      setDoc(doc(db, 'employees', ALICE), employeeDoc(ALICE, COMPANY_A)),
      setDoc(doc(db, 'employees', INES), employeeDoc(INES, COMPANY_A, { accountStatus: 'inactive' })),
      setDoc(doc(db, 'employees', DANI), employeeDoc(DANI, COMPANY_A, { accountStatus: 'disabled' })),
      setDoc(doc(db, 'employees', PEDRO), employeeDoc(PEDRO, COMPANY_A, {
        accountStatus: 'pending',
        hasTempPassword: true,
      })),
      setDoc(doc(db, 'employees', CAROL), employeeDoc(CAROL, COMPANY_B)),
      setDoc(doc(db, 'clockRecords', CLOCK_A_OPEN), clockDoc(CLOCK_A_OPEN, ALICE, COMPANY_A)),
      setDoc(doc(db, 'clockRecords', CLOCK_A_EDITED_OPEN),
          editedOpenClockDoc(CLOCK_A_EDITED_OPEN, ALICE, COMPANY_A)),
      setDoc(doc(db, 'clockRecords', CLOCK_A_CLOSED), clockDoc(CLOCK_A_CLOSED, ALICE, COMPANY_A, {
        clockOut: T_OUT,
        clockOutLat: 40.41,
        clockOutLng: -3.71,
        updatedAt: T_OUT,
      })),
      setDoc(doc(db, 'clockRecords', CLOCK_I_OPEN), clockDoc(CLOCK_I_OPEN, INES, COMPANY_A)),
      setDoc(doc(db, 'clockRecords', CLOCK_D_OPEN), clockDoc(CLOCK_D_OPEN, DANI, COMPANY_A)),
      setDoc(doc(db, 'time_off_requests', REQ_ALICE), timeOffDoc(COMPANY_A, ALICE)),
      setDoc(doc(db, 'time_off_requests', REQ_INES), timeOffDoc(COMPANY_A, INES)),
      setDoc(doc(db, 'time_off_requests', REQ_DANI), timeOffDoc(COMPANY_A, DANI)),
      setDoc(doc(db, 'conversations', GROUP_A),
          conversationDoc(COMPANY_A, [COMPANY_A, ALICE, INES, DANI, PEDRO], { isGroup: true, title: 'Todos' })),
      setDoc(doc(db, 'employee_schedule_months', monthId(COMPANY_A, ALICE, MONTH)),
          monthDoc(COMPANY_A, ALICE, MONTH)),
      setDoc(doc(db, 'employee_schedule_months', monthId(COMPANY_A, INES, MONTH)),
          monthDoc(COMPANY_A, INES, MONTH)),
      setDoc(doc(db, 'employee_schedule_months', monthId(COMPANY_A, DANI, MONTH)),
          monthDoc(COMPANY_A, DANI, MONTH)),
    ]);
  });
}

describe('Fase 8 — reglas de fichaje, consultas de empresa, accountStatus y uid', function() {
  this.timeout(30000);

  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        host: EMULATOR_HOST,
        port: EMULATOR_PORT,
        rules: fs.readFileSync(RULES_PATH, 'utf8'),
      },
    });
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await seedBase();
  });

  after(async () => {
    await testEnv.cleanup();
  });

  const clockAs = (uid, id) => doc(asUser(uid), 'clockRecords', id);

  // =========================================================================
  describe('clockRecords: cierre del empleado (solo clockOut/clockOutLat/clockOutLng/updatedAt)', () => {
    it('cierra un fichaje abierto que la empresa editó (isEdited=true) con update parcial → ok', () =>
      assertSucceeds(updateDoc(clockAs(ALICE, CLOCK_A_EDITED_OPEN), closePayload())));

    it('cierra un fichaje abierto sin editar con update parcial → ok', () =>
      assertSucceeds(updateDoc(clockAs(ALICE, CLOCK_A_OPEN), closePayload())));

    it('cierra un fichaje editado reescribiendo el doc completo FRESCO (mismos metadatos) → ok', () =>
      assertSucceeds(updateDoc(clockAs(ALICE, CLOCK_A_EDITED_OPEN), {
        ...editedOpenClockDoc(CLOCK_A_EDITED_OPEN, ALICE, COMPANY_A),
        ...closePayload(),
      })));

    it('cierra un fichaje editado con un modelo OBSOLETO (isEdited=false, clockIn antiguo) → denegado', () =>
      assertFails(updateDoc(clockAs(ALICE, CLOCK_A_EDITED_OPEN), {
        ...clockDoc(CLOCK_A_EDITED_OPEN, ALICE, COMPANY_A),
        ...closePayload(),
      })));

    it('al cerrar NO puede poner isEdited=false en un fichaje editado', () =>
      assertFails(updateDoc(clockAs(ALICE, CLOCK_A_EDITED_OPEN), { ...closePayload(), isEdited: false })));

    it('al cerrar NO puede borrar el motivo de edición', () =>
      assertFails(updateDoc(clockAs(ALICE, CLOCK_A_EDITED_OPEN), { ...closePayload(), editReason: null })));

    it('al cerrar NO puede vaciar editedFields', () =>
      assertFails(updateDoc(clockAs(ALICE, CLOCK_A_EDITED_OPEN), { ...closePayload(), editedFields: [] })));

    it('NO puede marcar isEdited=true', () =>
      assertFails(updateDoc(clockAs(ALICE, CLOCK_A_OPEN), {
        ...closePayload(), isEdited: true, editedBy: 'employee',
      })));

    it('NO puede cambiar clockIn', () =>
      assertFails(updateDoc(clockAs(ALICE, CLOCK_A_OPEN), { ...closePayload(), clockIn: T_EDITED_IN })));

    it('NO puede cambiar la ubicación de entrada', () =>
      assertFails(updateDoc(clockAs(ALICE, CLOCK_A_OPEN), { ...closePayload(), clockInLat: 0 })));

    it('NO puede modificar un fichaje YA CERRADO (cambiar clockOut)', () =>
      assertFails(updateDoc(clockAs(ALICE, CLOCK_A_CLOSED), closePayload(T_OUT_2))));

    it('NO puede reabrir un fichaje cerrado (clockOut=null)', () =>
      assertFails(updateDoc(clockAs(ALICE, CLOCK_A_CLOSED), { clockOut: null, updatedAt: Timestamp.now() })));

    it('NO puede cambiar employeeId/companyId/createdAt/id al cerrar', async () => {
      await assertFails(updateDoc(clockAs(ALICE, CLOCK_A_OPEN), { ...closePayload(), employeeId: INES }));
      await assertFails(updateDoc(clockAs(ALICE, CLOCK_A_OPEN), { ...closePayload(), companyId: COMPANY_B }));
      await assertFails(updateDoc(clockAs(ALICE, CLOCK_A_OPEN), { ...closePayload(), createdAt: T_OUT }));
      await assertFails(updateDoc(clockAs(ALICE, CLOCK_A_OPEN), { ...closePayload(), id: 'otro' }));
    });

    it('un compañero NO cierra el fichaje de otro', () =>
      assertFails(updateDoc(clockAs(INES, CLOCK_A_OPEN), closePayload())));

    it('la empresa sigue pudiendo corregir (isEdited=true) un fichaje abierto o cerrado', async () => {
      const edit = {
        clockIn: T_EDITED_IN,
        isEdited: true,
        editedBy: 'company',
        editedAt: Timestamp.now(),
        editReason: 'Corrección',
        editedFields: ['clockIn'],
        updatedAt: Timestamp.now(),
      };
      await assertSucceeds(updateDoc(clockAs(COMPANY_A, CLOCK_A_OPEN), edit));
      await assertSucceeds(updateDoc(clockAs(COMPANY_A, CLOCK_A_CLOSED), { ...edit, clockOut: T_OUT_2 }));
    });
  });

  // =========================================================================
  describe('clockRecords: consulta de fichajes de un empleado por la empresa (CAND-011)', () => {
    it('empresa: employeeId == E + companyId == uid, orderBy clockIn desc → ok', () =>
      assertSucceeds(getDocs(query(collection(asUser(COMPANY_A), 'clockRecords'),
          where('employeeId', '==', ALICE),
          where('companyId', '==', COMPANY_A),
          orderBy('clockIn', 'desc')))));

    it('empresa: solo employeeId == E (sin companyId) → denegada (no demostrable)', () =>
      assertFails(getDocs(query(collection(asUser(COMPANY_A), 'clockRecords'),
          where('employeeId', '==', ALICE),
          orderBy('clockIn', 'desc')))));

    it('otra empresa: employeeId == E + companyId == A → denegada', () =>
      assertFails(getDocs(query(collection(asUser(COMPANY_B), 'clockRecords'),
          where('employeeId', '==', ALICE),
          where('companyId', '==', COMPANY_A),
          orderBy('clockIn', 'desc')))));

    it('el propio empleado: employeeId == uid + companyId → ok', () =>
      assertSucceeds(getDocs(query(collection(asUser(ALICE), 'clockRecords'),
          where('employeeId', '==', ALICE),
          where('companyId', '==', COMPANY_A),
          orderBy('clockIn', 'desc')))));

    it('el propio empleado: solo employeeId == uid → ok (sin cambios)', () =>
      assertSucceeds(getDocs(query(collection(asUser(ALICE), 'clockRecords'),
          where('employeeId', '==', ALICE),
          orderBy('clockIn', 'desc')))));
  });

  // =========================================================================
  describe('accountStatus: empleados inactive/disabled no escriben', () => {
    const blocked = [
      { uid: INES, status: 'inactive', clock: CLOCK_I_OPEN, req: REQ_INES },
      { uid: DANI, status: 'disabled', clock: CLOCK_D_OPEN, req: REQ_DANI },
    ];

    for (const { uid, status, clock, req } of blocked) {
      describe(`empleado ${status} (${uid})`, () => {
        it('NO crea un fichaje', () =>
          assertFails(setDoc(clockAs(uid, `nuevo_${uid}`), clockDoc(`nuevo_${uid}`, uid, COMPANY_A))));

        it('NO cierra su fichaje abierto', () =>
          assertFails(updateDoc(clockAs(uid, clock), closePayload())));

        it('NO crea una solicitud de ausencia', () =>
          assertFails(setDoc(doc(asUser(uid), 'time_off_requests', `req_${uid}_nueva`),
              timeOffDoc(COMPANY_A, uid))));

        it('NO cancela su solicitud de ausencia', () =>
          assertFails(updateDoc(doc(asUser(uid), 'time_off_requests', req),
              { status: 'cancelled', updatedAt: Timestamp.now() })));

        it('NO crea una conversación', () =>
          assertFails(setDoc(doc(asUser(uid), 'conversations', `conv_${uid}`),
              conversationDoc(COMPANY_A, [uid, ALICE]))));

        it('NO envía mensajes al grupo aunque sea miembro', () =>
          assertFails(setDoc(doc(asUser(uid), 'conversations', GROUP_A, 'messages', `msg_${uid}`),
              messageDoc(GROUP_A, uid))));

        it('NO crea su mes de horario', () =>
          assertFails(setDoc(doc(asUser(uid), 'employee_schedule_months', monthId(COMPANY_A, uid, MONTH_NEXT)),
              monthDoc(COMPANY_A, uid, MONTH_NEXT), { merge: true })));

        it('NO edita su mes de horario', () =>
          assertFails(setDoc(doc(asUser(uid), 'employee_schedule_months', monthId(COMPANY_A, uid, MONTH)),
              { entries: { [`${MONTH}-12`]: { type: 'vacation' } }, updatedAt: Timestamp.now() },
              { merge: true })));

        it('sigue leyendo su ficha, su empresa y su fichaje (la lectura no cambia)', async () => {
          await assertSucceeds(getDoc(doc(asUser(uid), 'employees', uid)));
          await assertSucceeds(getDoc(doc(asUser(uid), 'companies', COMPANY_A)));
          await assertSucceeds(getDoc(clockAs(uid, clock)));
          await assertSucceeds(getDoc(doc(asUser(uid), 'time_off_requests', req)));
        });
      });
    }

    describe('empleado pending (pedro)', () => {
      it('activa su cuenta: pending → active con hasTempPassword=false → ok', () =>
        assertSucceeds(updateDoc(doc(asUser(PEDRO), 'employees', PEDRO),
            { accountStatus: 'active', hasTempPassword: false })));

      it('NO crea fichajes mientras está pending', () =>
        assertFails(setDoc(clockAs(PEDRO, 'nuevoPedro'), clockDoc('nuevoPedro', PEDRO, COMPANY_A))));

      it('tras activarse SÍ crea fichajes', async () => {
        await assertSucceeds(updateDoc(doc(asUser(PEDRO), 'employees', PEDRO),
            { accountStatus: 'active', hasTempPassword: false }));
        await assertSucceeds(setDoc(clockAs(PEDRO, 'nuevoPedro2'), clockDoc('nuevoPedro2', PEDRO, COMPANY_A)));
      });
    });

    describe('empleado activo (alice): controles positivos', () => {
      it('crea un fichaje', () =>
        assertSucceeds(setDoc(clockAs(ALICE, 'nuevoAlice'), clockDoc('nuevoAlice', ALICE, COMPANY_A))));

      it('crea una solicitud de ausencia', () =>
        assertSucceeds(setDoc(doc(asUser(ALICE), 'time_off_requests', 'reqAliceNueva'),
            timeOffDoc(COMPANY_A, ALICE))));

      it('cancela su solicitud', () =>
        assertSucceeds(updateDoc(doc(asUser(ALICE), 'time_off_requests', REQ_ALICE),
            { status: 'cancelled', updatedAt: Timestamp.now() })));

      it('crea una conversación', () =>
        assertSucceeds(setDoc(doc(asUser(ALICE), 'conversations', 'convAlice'),
            conversationDoc(COMPANY_A, [ALICE, INES]))));

      it('envía un mensaje al grupo', () =>
        assertSucceeds(setDoc(doc(asUser(ALICE), 'conversations', GROUP_A, 'messages', 'msgAlice'),
            messageDoc(GROUP_A, ALICE))));

      it('crea y edita su mes de horario', async () => {
        await assertSucceeds(setDoc(
            doc(asUser(ALICE), 'employee_schedule_months', monthId(COMPANY_A, ALICE, MONTH_NEXT)),
            monthDoc(COMPANY_A, ALICE, MONTH_NEXT), { merge: true }));
        await assertSucceeds(setDoc(
            doc(asUser(ALICE), 'employee_schedule_months', monthId(COMPANY_A, ALICE, MONTH)),
            { entries: { [`${MONTH}-12`]: { type: 'vacation' } }, updatedAt: Timestamp.now() },
            { merge: true }));
      });
    });

    describe('la empresa no se ve afectada', () => {
      it('crea fichajes de un empleado inactive (corrección manual)', () =>
        assertSucceeds(setDoc(clockAs(COMPANY_A, 'coInes'), clockDoc('coInes', INES, COMPANY_A))));

      it('crea el grupo y envía mensajes', async () => {
        await assertSucceeds(setDoc(doc(asUser(COMPANY_A), 'conversations', 'convCo'),
            conversationDoc(COMPANY_A, [COMPANY_A, ALICE])));
        await assertSucceeds(setDoc(doc(asUser(COMPANY_A), 'conversations', GROUP_A, 'messages', 'msgCo'),
            messageDoc(GROUP_A, COMPANY_A)));
      });

      it('crea y edita meses de horario', async () => {
        await assertSucceeds(setDoc(
            doc(asUser(COMPANY_A), 'employee_schedule_months', monthId(COMPANY_A, INES, MONTH_NEXT)),
            monthDoc(COMPANY_A, INES, MONTH_NEXT), { merge: true }));
        await assertSucceeds(setDoc(
            doc(asUser(COMPANY_A), 'employee_schedule_months', monthId(COMPANY_A, INES, MONTH)),
            { entries: { [`${MONTH}-12`]: { type: 'vacation' } }, updatedAt: Timestamp.now() },
            { merge: true }));
      });

      it('decide sobre solicitudes de empleados inactive', () =>
        assertSucceeds(updateDoc(doc(asUser(COMPANY_A), 'time_off_requests', REQ_INES),
            { status: 'approved', decidedBy: COMPANY_A, updatedAt: Timestamp.now() })));
    });
  });

  // =========================================================================
  describe('employees.uid inmutable en update', () => {
    const aliceAs = (uid) => doc(asUser(uid), 'employees', ALICE);

    it('la empresa NO cambia el uid de su empleado', () =>
      assertFails(updateDoc(aliceAs(COMPANY_A), { uid: 'otroUid' })));

    it('el empleado NO cambia su propio uid', () =>
      assertFails(updateDoc(aliceAs(ALICE), { uid: 'otroUid' })));

    it('la empresa NO elimina el campo uid', () =>
      assertFails(setDoc(aliceAs(COMPANY_A), { ...employeeDoc(ALICE, COMPANY_A), uid: null })));

    it('la empresa edita otros campos conservando el uid → ok', () =>
      assertSucceeds(updateDoc(aliceAs(COMPANY_A), { uid: ALICE, name: 'Alicia', hourlyRate: 13 })));

    it('el empleado reescribe su doc completo con el mismo uid → ok', () =>
      assertSucceeds(updateDoc(aliceAs(ALICE), { ...employeeDoc(ALICE, COMPANY_A), name: 'Alicia' })));
  });
});
