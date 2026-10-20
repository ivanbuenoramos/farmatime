'use strict';

/**
 * Tests unitarios de las reglas de seguridad de Firestore (firestore.rules).
 *
 * Requisitos:
 *   - Emulador de Firestore corriendo en 127.0.0.1:8080 (`firebase emulators:start`).
 *   - `npm test` desde functions/.
 *
 * Actores de la suite:
 *   - companyA / companyB: dos farmacias (uid de Auth == id de companies/{uid}).
 *   - alice, bob: empleados activos de companyA (compañeros).
 *   - pedro: empleado de companyA en estado `pending` con contraseña temporal.
 *   - carol: empleada activa de companyB.
 *   - stranger: usuario autenticado sin ficha de empresa ni de empleado.
 *
 * El emulador avisa por usar un projectId distinto al de singleProjectMode
 * (farmatime-app); es solo un aviso y permite aislar los datos de prueba.
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
  addDoc,
  updateDoc,
  deleteDoc,
  query,
  where,
  orderBy,
  limit,
  Timestamp,
  deleteField,
  increment,
  setLogLevel,
} = require('firebase/firestore');

// El SDK registra cada PERMISSION_DENIED como error gRPC; en esta suite las
// denegaciones son el resultado esperado, así que silenciamos ese ruido.
setLogLevel('silent');

const PROJECT_ID = 'farmatime-rules-test';
const RULES_PATH = path.resolve(__dirname, '..', '..', '..', 'firestore.rules');
const EMULATOR_HOST = '127.0.0.1';
const EMULATOR_PORT = 8080;

// ---------- Actores ----------
const COMPANY_A = 'companyA';
const COMPANY_B = 'companyB';
const ALICE = 'alice';
const BOB = 'bob';
const PEDRO = 'pedro';
const CAROL = 'carol';
const STRANGER = 'stranger';

// ---------- Ids de documentos sembrados ----------
const CLOCK_A1 = 'clockA1'; // alice / companyA (abierto, sin clockOut)
const CLOCK_B1 = 'clockB1'; // bob / companyA
const CLOCK_C1 = 'clockC1'; // carol / companyB
const LOG_A1 = 'logA1'; // auditLog de CLOCK_A1
const REQ_ALICE_REQUESTED = 'reqAliceRequested';
const REQ_ALICE_PROPOSED = 'reqAliceProposed';
const REQ_ALICE_APPROVED = 'reqAliceApproved';
const REQ_BOB_REQUESTED = 'reqBobRequested';
const REQ_CAROL_REQUESTED = 'reqCarolRequested';
const CONV_AB = 'convAB'; // 1:1 alice-bob (companyA)
const GROUP_A = 'groupA'; // grupo "Todos" de companyA (companyA, alice, bob)
const CONV_C = 'convC'; // 1:1 carol-companyB
const MSG_1 = 'msg1'; // mensaje de alice en CONV_AB
const TPL_A = 'tplA';
const TPL_B = 'tplB';
const RULE_A = 'ruleA';
const RULE_B = 'ruleB';
const MONTH = '2026-11';
const MONTH_NEXT = '2026-12';
const REPORT_A = 'reportA';
const REPORT_B = 'reportB';
const TOKEN_1 = 'tokenAlice1';

const monthId = (companyId, employeeId, month) => `${companyId}__${employeeId}__${month}`;

const T_EARLIER = Timestamp.fromDate(new Date('2026-10-01T06:00:00Z'));
const T_CREATED = Timestamp.fromDate(new Date('2026-10-01T08:00:00Z'));
const T_LATER = Timestamp.fromDate(new Date('2026-10-01T16:00:00Z'));

// ---------- Fábricas de documentos (misma forma que escribe la app) ----------
function companyDoc(id, extra = {}) {
  return {
    id,
    email: `${id}@farmatime.test`,
    logoUrl: null,
    legalName: `Farmacia ${id}`,
    vatNumber: 'B12345678',
    address: null,
    phoneNumber: null,
    authMethod: 'email',
    contractedSeats: 1,
    billingStatus: 'none',
    currentPeriodEnd: null,
    verifiedEmail: true,
    verifiedPhone: false,
    createdAt: T_CREATED,
    updatedAt: T_CREATED,
    ...extra,
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
    clockIn: T_CREATED,
    clockOut: null,
    clockInLat: null,
    clockInLng: null,
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

function auditDoc(id, entryId, companyId, employeeId, actorUid, extra = {}) {
  return {
    id,
    entryId,
    companyId,
    employeeId,
    action: 'edited',
    actorUid,
    actorRole: actorUid === companyId ? 'company' : 'employee',
    actorName: null,
    reason: 'Corrección de prueba',
    changes: [{ field: 'clockOut', oldValue: null, newValue: '2026-10-01T16:00:00.000Z' }],
    at: T_LATER,
    ...extra,
  };
}

function timeOffDoc(companyId, employeeId, status, extra = {}) {
  return {
    companyId,
    employeeId,
    type: 'vacation',
    status,
    dates: ['2026-11-02', '2026-11-03'],
    proposedDates: [],
    createdAt: T_CREATED,
    updatedAt: T_CREATED,
    ...extra,
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

function messageDoc(conversationId, senderId, extra = {}) {
  return {
    conversationId,
    senderId,
    text: 'Hola',
    createdAt: T_CREATED,
    ...extra,
  };
}

function templateDoc(companyId, extra = {}) {
  return {
    companyId,
    name: 'Mañana',
    startTime: '09:00',
    endTime: '14:00',
    active: true,
    createdAt: T_CREATED,
    updatedAt: T_CREATED,
    ...extra,
  };
}

function ruleDoc(companyId, employeeId, extra = {}) {
  return {
    companyId,
    employeeId,
    active: true,
    weekdays: [1, 2, 3, 4, 5],
    templateId: TPL_A,
    startDate: '2026-10-01',
    createdAt: T_CREATED,
    updatedAt: T_CREATED,
    ...extra,
  };
}

function monthDoc(companyId, employeeId, month, extra = {}) {
  return {
    companyId,
    employeeId,
    month,
    entries: { [`${month}-05`]: { type: 'work', templateId: TPL_A } },
    createdAt: T_CREATED,
    updatedAt: T_CREATED,
    ...extra,
  };
}

function reportDoc(companyId, employeeId, extra = {}) {
  return {
    companyId,
    employeeId,
    periodStart: '2026-09-01',
    periodEnd: '2026-09-30',
    storagePath: `clockReports/${companyId}/${employeeId}/2026-09.pdf`,
    createdAt: T_CREATED,
    ...extra,
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

function asAnon() {
  if (!dbCache.has('__anon__')) {
    dbCache.set('__anon__', testEnv.unauthenticatedContext().firestore());
  }
  return dbCache.get('__anon__');
}

async function seed(fn) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await fn(ctx.firestore());
  });
}

async function seedBase() {
  await seed(async (db) => {
    await Promise.all([
      // Empresas
      setDoc(doc(db, 'companies', COMPANY_A), companyDoc(COMPANY_A)),
      setDoc(doc(db, 'companies', COMPANY_B), companyDoc(COMPANY_B)),
      setDoc(doc(db, 'companies', COMPANY_A, 'subscription', 'current'), {
        status: 'active',
        platform: 'ios',
        productId: 'farmatime_5',
        expiresAt: T_LATER,
      }),
      // Empleados
      setDoc(doc(db, 'employees', ALICE), employeeDoc(ALICE, COMPANY_A)),
      setDoc(doc(db, 'employees', BOB), employeeDoc(BOB, COMPANY_A)),
      setDoc(doc(db, 'employees', PEDRO), employeeDoc(PEDRO, COMPANY_A, {
        accountStatus: 'pending',
        hasTempPassword: true,
      })),
      setDoc(doc(db, 'employees', CAROL), employeeDoc(CAROL, COMPANY_B)),
      setDoc(doc(db, 'employees', ALICE, 'private', 'credentials'), {
        tempPassword: 'Temporal123!',
        createdAt: T_CREATED,
      }),
      // Fichajes
      setDoc(doc(db, 'clockRecords', CLOCK_A1), clockDoc(CLOCK_A1, ALICE, COMPANY_A)),
      setDoc(doc(db, 'clockRecords', CLOCK_B1), clockDoc(CLOCK_B1, BOB, COMPANY_A)),
      setDoc(doc(db, 'clockRecords', CLOCK_C1), clockDoc(CLOCK_C1, CAROL, COMPANY_B)),
      setDoc(
          doc(db, 'clockRecords', CLOCK_A1, 'auditLog', LOG_A1),
          auditDoc(LOG_A1, CLOCK_A1, COMPANY_A, ALICE, COMPANY_A),
      ),
      // Ausencias
      setDoc(doc(db, 'time_off_requests', REQ_ALICE_REQUESTED),
          timeOffDoc(COMPANY_A, ALICE, 'requested')),
      setDoc(doc(db, 'time_off_requests', REQ_ALICE_PROPOSED),
          timeOffDoc(COMPANY_A, ALICE, 'proposed', {
            proposedDates: ['2026-11-09', '2026-11-10'],
            companyNote: 'Mejor la semana siguiente',
          })),
      setDoc(doc(db, 'time_off_requests', REQ_ALICE_APPROVED),
          timeOffDoc(COMPANY_A, ALICE, 'approved', { decidedBy: COMPANY_A })),
      setDoc(doc(db, 'time_off_requests', REQ_BOB_REQUESTED),
          timeOffDoc(COMPANY_A, BOB, 'requested')),
      setDoc(doc(db, 'time_off_requests', REQ_CAROL_REQUESTED),
          timeOffDoc(COMPANY_B, CAROL, 'requested')),
      // Chat
      setDoc(doc(db, 'conversations', CONV_AB), conversationDoc(COMPANY_A, [ALICE, BOB])),
      setDoc(doc(db, 'conversations', GROUP_A),
          conversationDoc(COMPANY_A, [COMPANY_A, ALICE, BOB], { isGroup: true, title: 'Todos' })),
      setDoc(doc(db, 'conversations', CONV_C), conversationDoc(COMPANY_B, [CAROL, COMPANY_B])),
      setDoc(doc(db, 'conversations', CONV_AB, 'messages', MSG_1), messageDoc(CONV_AB, ALICE)),
      // Horarios
      setDoc(doc(db, 'company_shift_templates', TPL_A), templateDoc(COMPANY_A)),
      setDoc(doc(db, 'company_shift_templates', TPL_B), templateDoc(COMPANY_B)),
      setDoc(doc(db, 'employee_schedule_rules', RULE_A), ruleDoc(COMPANY_A, ALICE)),
      setDoc(doc(db, 'employee_schedule_rules', RULE_B), ruleDoc(COMPANY_B, CAROL)),
      setDoc(doc(db, 'employee_schedule_months', monthId(COMPANY_A, ALICE, MONTH)),
          monthDoc(COMPANY_A, ALICE, MONTH)),
      setDoc(doc(db, 'employee_schedule_months', monthId(COMPANY_A, BOB, MONTH)),
          monthDoc(COMPANY_A, BOB, MONTH)),
      setDoc(doc(db, 'employee_schedule_months', monthId(COMPANY_B, CAROL, MONTH)),
          monthDoc(COMPANY_B, CAROL, MONTH)),
      // Reportes
      setDoc(doc(db, 'clockReports', REPORT_A), reportDoc(COMPANY_A, ALICE)),
      setDoc(doc(db, 'clockReports', REPORT_B), reportDoc(COMPANY_B, CAROL)),
      // FCM
      setDoc(doc(db, 'user_fcm_tokens', ALICE), { updatedAt: T_CREATED }),
      setDoc(doc(db, 'user_fcm_tokens', ALICE, 'tokens', TOKEN_1), {
        token: TOKEN_1,
        platform: 'ios',
        updatedAt: T_CREATED,
      }),
      // Backend-only
      setDoc(doc(db, 'mail', 'mail1'), {
        to: 'alguien@farmatime.test',
        message: { subject: 'Hola', text: 'Prueba' },
      }),
      setDoc(doc(db, '_appleEvents', 'evt1'), { notificationUUID: 'uuid-1', processedAt: T_CREATED }),
      setDoc(doc(db, 'random', 'x'), { foo: 'bar' }),
    ]);
  });
}

describe('Reglas de seguridad de Firestore (firestore.rules)', function() {
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

  // =========================================================================
  describe('Sin autenticar', () => {
    it('no lee la ficha de una empresa', () =>
      assertFails(getDoc(doc(asAnon(), 'companies', COMPANY_A))));

    it('no edita la ficha de una empresa', () =>
      assertFails(updateDoc(doc(asAnon(), 'companies', COMPANY_A), { legalName: 'Hackeada' })));

    it('no crea una empresa', () =>
      assertFails(setDoc(doc(asAnon(), 'companies', 'anonCo'), companyDoc('anonCo'))));

    it('no lee un empleado', () =>
      assertFails(getDoc(doc(asAnon(), 'employees', ALICE))));

    it('no edita un empleado', () =>
      assertFails(updateDoc(doc(asAnon(), 'employees', ALICE), { name: 'X' })));

    it('no lee un fichaje', () =>
      assertFails(getDoc(doc(asAnon(), 'clockRecords', CLOCK_A1))));

    it('no crea un fichaje', () =>
      assertFails(setDoc(doc(asAnon(), 'clockRecords', 'anonClock'),
          clockDoc('anonClock', ALICE, COMPANY_A))));

    it('no lista fichajes por employeeId', () =>
      assertFails(getDocs(query(collection(asAnon(), 'clockRecords'),
          where('employeeId', '==', ALICE)))));

    it('no lee una conversación', () =>
      assertFails(getDoc(doc(asAnon(), 'conversations', CONV_AB))));

    it('no crea una conversación', () =>
      assertFails(addDoc(collection(asAnon(), 'conversations'),
          conversationDoc(COMPANY_A, [ALICE, BOB]))));

    it('no lee un mensaje', () =>
      assertFails(getDoc(doc(asAnon(), 'conversations', CONV_AB, 'messages', MSG_1))));

    it('no lee una solicitud de ausencia', () =>
      assertFails(getDoc(doc(asAnon(), 'time_off_requests', REQ_ALICE_REQUESTED))));

    it('no crea una solicitud de ausencia', () =>
      assertFails(addDoc(collection(asAnon(), 'time_off_requests'),
          timeOffDoc(COMPANY_A, ALICE, 'requested'))));

    it('no lee ni escribe tokens FCM', async () => {
      await assertFails(getDoc(doc(asAnon(), 'user_fcm_tokens', ALICE, 'tokens', TOKEN_1)));
      await assertFails(setDoc(doc(asAnon(), 'user_fcm_tokens', ALICE, 'tokens', 'anon'), {
        token: 'anon',
      }));
    });
  });

  // =========================================================================
  describe('companies', () => {
    const refA = () => doc(asUser(COMPANY_A), 'companies', COMPANY_A);

    it('la empresa lee su propia ficha', () =>
      assertSucceeds(getDoc(refA())));

    it('la empresa edita campos de perfil de su ficha (legalName, address)', () =>
      assertSucceeds(updateDoc(refA(), {
        legalName: 'Farmacia Central',
        address: { street: 'Calle Mayor 1', city: 'Madrid' },
        updatedAt: Timestamp.now(),
      })));

    it('la empresa puede reescribir su ficha completa (toFirestore) sin tocar facturación', () =>
      assertSucceeds(updateDoc(refA(), companyDoc(COMPANY_A, {
        legalName: 'Farmacia Reescrita',
        updatedAt: Timestamp.now(),
      }))));

    it('otra empresa NO lee la ficha', () =>
      assertFails(getDoc(doc(asUser(COMPANY_B), 'companies', COMPANY_A))));

    it('otra empresa NO edita la ficha', () =>
      assertFails(updateDoc(doc(asUser(COMPANY_B), 'companies', COMPANY_A), {
        legalName: 'Pirateada',
      })));

    it('un empleado de la empresa lee la ficha', () =>
      assertSucceeds(getDoc(doc(asUser(ALICE), 'companies', COMPANY_A))));

    it('un empleado de la empresa NO edita la ficha', () =>
      assertFails(updateDoc(doc(asUser(ALICE), 'companies', COMPANY_A), {
        legalName: 'Cambiada por empleado',
      })));

    it('un empleado de OTRA empresa NO lee la ficha', () =>
      assertFails(getDoc(doc(asUser(CAROL), 'companies', COMPANY_A))));

    it('un usuario autenticado sin ficha (ni empresa ni empleado) NO lee la ficha', () =>
      assertFails(getDoc(doc(asUser(STRANGER), 'companies', COMPANY_A))));

    describe('campos de facturación protegidos en update', () => {
      it('la empresa NO puede cambiar billingStatus', () =>
        assertFails(updateDoc(refA(), { billingStatus: 'active' })));

      it('la empresa NO puede eliminar billingStatus', () =>
        assertFails(updateDoc(refA(), { billingStatus: deleteField() })));

      it('la empresa NO puede cambiar contractedSeats', () =>
        assertFails(updateDoc(refA(), { contractedSeats: 5 })));

      it('la empresa NO puede escribir subscription', () =>
        assertFails(updateDoc(refA(), {
          subscription: { status: 'active', platform: 'ios', productId: 'farmatime_10' },
        })));

      it('la empresa NO puede cambiar currentPeriodEnd', () =>
        assertFails(updateDoc(refA(), {
          currentPeriodEnd: Timestamp.fromDate(new Date('2030-01-01T00:00:00Z')),
        })));

      it('la empresa NO puede escribir canceledAt', () =>
        assertFails(updateDoc(refA(), { canceledAt: Timestamp.now() })));

      it('la empresa NO puede falsear la suscripción con un set(merge) completo (mock IAP)', () =>
        assertFails(setDoc(refA(), {
          subscription: { status: 'active', platform: 'ios' },
          billingStatus: 'active',
          contractedSeats: 10,
          currentPeriodEnd: Timestamp.fromDate(new Date('2030-01-01T00:00:00Z')),
        }, { merge: true })));
    });

    describe('create', () => {
      const NEW_CO = 'newCo';
      const refNew = () => doc(asUser(NEW_CO), 'companies', NEW_CO);

      it('create con billingStatus active → denegado', () =>
        assertFails(setDoc(refNew(), companyDoc(NEW_CO, { billingStatus: 'active' }))));

      it('create con contractedSeats 5 → denegado', () =>
        assertFails(setDoc(refNew(), companyDoc(NEW_CO, { contractedSeats: 5 }))));

      it('create con billingStatus none y contractedSeats 1 → permitido', () =>
        assertSucceeds(setDoc(refNew(), companyDoc(NEW_CO, {
          billingStatus: 'none',
          contractedSeats: 1,
        }))));

      it('create sin campos de facturación → permitido', () => {
        const data = companyDoc(NEW_CO);
        delete data.billingStatus;
        delete data.contractedSeats;
        delete data.currentPeriodEnd;
        return assertSucceeds(setDoc(refNew(), data));
      });

      it('create de una empresa con id distinto al uid → denegado', () =>
        assertFails(setDoc(doc(asUser(COMPANY_A), 'companies', NEW_CO), companyDoc(NEW_CO))));

      it('create por un empleado → denegado', () =>
        assertFails(setDoc(doc(asUser(ALICE), 'companies', NEW_CO), companyDoc(NEW_CO))));
    });

    it('delete denegado incluso para la propia empresa', () =>
      assertFails(deleteDoc(refA())));

    describe('subcolección subscription', () => {
      const subA = (uid) => doc(asUser(uid), 'companies', COMPANY_A, 'subscription', 'current');

      it('la empresa lee su subscription/current', () =>
        assertSucceeds(getDoc(subA(COMPANY_A))));

      it('otra empresa NO lee la subscription', () =>
        assertFails(getDoc(subA(COMPANY_B))));

      it('un empleado de la empresa NO lee la subscription', () =>
        assertFails(getDoc(subA(ALICE))));

      it('la empresa NO escribe la subscription (update)', () =>
        assertFails(updateDoc(subA(COMPANY_A), { status: 'active' })));

      it('la empresa NO escribe la subscription (set merge)', () =>
        assertFails(setDoc(subA(COMPANY_A), { status: 'active' }, { merge: true })));

      it('la empresa NO crea otros docs en subscription', () =>
        assertFails(setDoc(doc(asUser(COMPANY_A), 'companies', COMPANY_A, 'subscription', 'otro'), {
          status: 'active',
        })));

      it('un empleado NO escribe la subscription', () =>
        assertFails(setDoc(subA(ALICE), { status: 'active' }, { merge: true })));

      it('la empresa NO borra la subscription', () =>
        assertFails(deleteDoc(subA(COMPANY_A))));
    });
  });

  // =========================================================================
  describe('employees', () => {
    const aliceAs = (uid) => doc(asUser(uid), 'employees', ALICE);

    describe('create', () => {
      it('create desde cliente denegado incluso para la empresa', () =>
        assertFails(setDoc(doc(asUser(COMPANY_A), 'employees', 'nuevo'),
            employeeDoc('nuevo', COMPANY_A))));

      it('create denegado para el propio uid (auto-alta)', () =>
        assertFails(setDoc(doc(asUser('nuevo'), 'employees', 'nuevo'),
            employeeDoc('nuevo', COMPANY_A))));

      it('create denegado para un empleado existente', () =>
        assertFails(setDoc(doc(asUser(ALICE), 'employees', 'nuevo'),
            employeeDoc('nuevo', COMPANY_A))));
    });

    describe('update por la empresa', () => {
      it('la empresa actualiza condiciones laborales de su empleado', () =>
        assertSucceeds(updateDoc(aliceAs(COMPANY_A), {
          hourlyRate: 15,
          role: 'technician',
          position: 'Técnico',
          vacationDaysPer30: 3,
          updatedAt: Timestamp.now(),
        })));

      it('la empresa cambia el accountStatus de su empleado (inactive)', () =>
        assertSucceeds(updateDoc(aliceAs(COMPANY_A), { accountStatus: 'inactive' })));

      it('la empresa marca a su empleado como deleted (borrado lógico)', () =>
        assertSucceeds(updateDoc(aliceAs(COMPANY_A), { accountStatus: 'deleted' })));

      it('la empresa NO puede cambiar el companyId de su empleado', () =>
        assertFails(updateDoc(aliceAs(COMPANY_A), { companyId: COMPANY_B })));

      it('otra empresa NO actualiza al empleado', () =>
        assertFails(updateDoc(aliceAs(COMPANY_B), { hourlyRate: 1 })));

      it('otra empresa NO puede "robar" al empleado cambiando companyId', () =>
        assertFails(updateDoc(aliceAs(COMPANY_B), { companyId: COMPANY_B })));
    });

    describe('update por el propio empleado', () => {
      it('el empleado edita name y photoUrl', () =>
        assertSucceeds(updateDoc(aliceAs(ALICE), {
          name: 'Alicia García',
          photoUrl: 'https://cdn.farmatime.test/alice.jpg',
          updatedAt: Timestamp.now(),
        })));

      it('el empleado puede reescribir su doc completo (toJson sin hireDate/createdAt) sin cambiar condiciones', () => {
        // Desde la auditoría 2026-10-20 EmployeeRepositoryImpl.updateEmployee
        // excluye hireDate/createdAt del payload (los fija el backend).
        const payload = employeeDoc(ALICE, COMPANY_A, { name: 'Alicia', updatedAt: Timestamp.now() });
        delete payload.hireDate;
        delete payload.createdAt;
        return assertSucceeds(updateDoc(aliceAs(ALICE), payload));
      });

      it('el empleado NO puede reescribir hireDate como ISO string (comportamiento antiguo del cliente)', () =>
        assertFails(updateDoc(aliceAs(ALICE), {
          hireDate: '2026-10-01T08:00:00.000Z',
          updatedAt: Timestamp.now(),
        })));

      const protectedFields = {
        email: 'otra@farmatime.test',
        hourlyRate: 99,
        role: 'owner',
        roleOther: 'Jefe de todo',
        workdayType: 'part',
        vacationDaysPer30: 30,
        personalDaysPerYear: 99,
        position: 'Director general',
      };
      for (const [field, value] of Object.entries(protectedFields)) {
        it(`el empleado NO puede cambiar ${field}`, () =>
          assertFails(updateDoc(aliceAs(ALICE), { [field]: value })));
      }

      it('el empleado NO puede eliminar un campo protegido (hourlyRate)', () =>
        assertFails(updateDoc(aliceAs(ALICE), { hourlyRate: deleteField() })));

      it('el empleado NO puede cambiar su companyId', () =>
        assertFails(updateDoc(aliceAs(ALICE), { companyId: COMPANY_B })));

      it('un compañero NO edita el doc de otro empleado', () =>
        assertFails(updateDoc(aliceAs(BOB), { name: 'Cambiado por Bob' })));

      it('un empleado de otra empresa NO edita el doc', () =>
        assertFails(updateDoc(aliceAs(CAROL), { name: 'Cambiado por Carol' })));
    });

    describe('transiciones de accountStatus por el propio empleado', () => {
      const pedro = () => doc(asUser(PEDRO), 'employees', PEDRO);

      it('pending → active con hasTempPassword=false permitida', () =>
        assertSucceeds(updateDoc(pedro(), { accountStatus: 'active', hasTempPassword: false })));

      it('pending → active con hasTempPassword=true denegada', () =>
        assertFails(updateDoc(pedro(), { accountStatus: 'active', hasTempPassword: true })));

      it('pending → active sin cambiar hasTempPassword (sigue true) denegada', () =>
        assertFails(updateDoc(pedro(), { accountStatus: 'active' })));

      it('pending → disabled por el propio empleado denegada', () =>
        assertFails(updateDoc(pedro(), { accountStatus: 'disabled' })));

      it('active → disabled por el propio empleado denegada', () =>
        assertFails(updateDoc(aliceAs(ALICE), { accountStatus: 'disabled' })));

      it('active → deleted por el propio empleado denegada', () =>
        assertFails(updateDoc(aliceAs(ALICE), { accountStatus: 'deleted' })));

      it('active → inactive por el propio empleado denegada', () =>
        assertFails(updateDoc(aliceAs(ALICE), { accountStatus: 'inactive' })));

      it('el empleado puede mantener su accountStatus al editar otros campos', () =>
        assertSucceeds(updateDoc(aliceAs(ALICE), { accountStatus: 'active', name: 'Ali' })));
    });

    describe('lectura', () => {
      it('el empleado lee su propio doc', () =>
        assertSucceeds(getDoc(aliceAs(ALICE))));

      it('un compañero de la misma empresa lee el doc', () =>
        assertSucceeds(getDoc(aliceAs(BOB))));

      it('la empresa lee a su empleado', () =>
        assertSucceeds(getDoc(aliceAs(COMPANY_A))));

      it('un empleado de OTRA empresa NO lee el doc', () =>
        assertFails(getDoc(aliceAs(CAROL))));

      it('otra empresa NO lee el doc', () =>
        assertFails(getDoc(aliceAs(COMPANY_B))));

      it('un usuario sin ficha NO lee el doc', () =>
        assertFails(getDoc(aliceAs(STRANGER))));

      it('query de plantilla (companyId == A) por un empleado de A → ok', () =>
        assertSucceeds(getDocs(query(collection(asUser(ALICE), 'employees'),
            where('companyId', '==', COMPANY_A)))));

      it('query de plantilla (companyId == A) por la empresa A → ok', () =>
        assertSucceeds(getDocs(query(collection(asUser(COMPANY_A), 'employees'),
            where('companyId', '==', COMPANY_A)))));

      it('query de plantilla con accountStatus != deleted por la empresa → ok', () =>
        assertSucceeds(getDocs(query(collection(asUser(COMPANY_A), 'employees'),
            where('accountStatus', '!=', 'deleted'),
            where('companyId', '==', COMPANY_A)))));

      it('query de plantilla de A por un empleado de B → denegada', () =>
        assertFails(getDocs(query(collection(asUser(CAROL), 'employees'),
            where('companyId', '==', COMPANY_A)))));

      it('query de plantilla de A por la empresa B → denegada', () =>
        assertFails(getDocs(query(collection(asUser(COMPANY_B), 'employees'),
            where('companyId', '==', COMPANY_A)))));

      it('query sin filtro de empresa → denegada', () =>
        assertFails(getDocs(collection(asUser(COMPANY_A), 'employees'))));
    });

    describe('delete', () => {
      it('delete denegado para la empresa', () =>
        assertFails(deleteDoc(aliceAs(COMPANY_A))));

      it('delete denegado para el propio empleado', () =>
        assertFails(deleteDoc(aliceAs(ALICE))));
    });

    describe('subcolección private/credentials', () => {
      const cred = (uid) => doc(asUser(uid), 'employees', ALICE, 'private', 'credentials');

      it('el dueño lee sus credenciales', () =>
        assertSucceeds(getDoc(cred(ALICE))));

      it('la empresa NO lee las credenciales del empleado', () =>
        assertFails(getDoc(cred(COMPANY_A))));

      it('un compañero NO lee las credenciales', () =>
        assertFails(getDoc(cred(BOB))));

      it('el dueño NO escribe sus credenciales', () =>
        assertFails(setDoc(cred(ALICE), { tempPassword: 'nueva' }, { merge: true })));

      it('la empresa NO escribe las credenciales', () =>
        assertFails(setDoc(cred(COMPANY_A), { tempPassword: 'nueva' }, { merge: true })));

      it('el dueño NO borra sus credenciales', () =>
        assertFails(deleteDoc(cred(ALICE))));
    });
  });

  // =========================================================================
  describe('clockRecords', () => {
    const clockA1As = (uid) => doc(asUser(uid), 'clockRecords', CLOCK_A1);

    describe('create', () => {
      it('el empleado crea su propio fichaje (isEdited=false) en su empresa', () =>
        assertSucceeds(setDoc(doc(asUser(ALICE), 'clockRecords', 'nuevoA'),
            clockDoc('nuevoA', ALICE, COMPANY_A))));

      it('la empresa crea un fichaje de su empresa', () =>
        assertSucceeds(setDoc(doc(asUser(COMPANY_A), 'clockRecords', 'nuevoCo'),
            clockDoc('nuevoCo', ALICE, COMPANY_A))));

      it('create con isEdited=true → denegado (empleado)', () =>
        assertFails(setDoc(doc(asUser(ALICE), 'clockRecords', 'editado'),
            clockDoc('editado', ALICE, COMPANY_A, { isEdited: true, editedBy: 'employee' }))));

      it('create con isEdited=true → denegado (empresa)', () =>
        assertFails(setDoc(doc(asUser(COMPANY_A), 'clockRecords', 'editadoCo'),
            clockDoc('editadoCo', ALICE, COMPANY_A, { isEdited: true, editedBy: 'company' }))));

      it('create sin el campo isEdited → denegado', () => {
        const data = clockDoc('sinFlag', ALICE, COMPANY_A);
        delete data.isEdited;
        return assertFails(setDoc(doc(asUser(ALICE), 'clockRecords', 'sinFlag'), data));
      });

      it('create para otra companyId → denegado', () =>
        assertFails(setDoc(doc(asUser(ALICE), 'clockRecords', 'ajeno'),
            clockDoc('ajeno', ALICE, COMPANY_B))));

      it('un empleado de otra empresa NO crea fichajes en la empresa A', () =>
        assertFails(setDoc(doc(asUser(CAROL), 'clockRecords', 'intruso'),
            clockDoc('intruso', CAROL, COMPANY_A))));

      it('otra empresa NO crea fichajes en la empresa A', () =>
        assertFails(setDoc(doc(asUser(COMPANY_B), 'clockRecords', 'intrusoCo'),
            clockDoc('intrusoCo', ALICE, COMPANY_A))));

      it('un usuario sin ficha NO crea fichajes', () =>
        assertFails(setDoc(doc(asUser(STRANGER), 'clockRecords', 'stranger'),
            clockDoc('stranger', STRANGER, COMPANY_A))));
    });

    describe('update por el empleado dueño', () => {
      it('cierra su fichaje (clockOut) sin isEdited → ok', () =>
        assertSucceeds(updateDoc(clockA1As(ALICE), {
          clockOut: T_LATER,
          clockOutLat: 40.4,
          clockOutLng: -3.7,
          updatedAt: Timestamp.now(),
        })));

      it('reescribe su fichaje completo (toJson) al fichar la salida → ok', () =>
        assertSucceeds(updateDoc(clockA1As(ALICE), clockDoc(CLOCK_A1, ALICE, COMPANY_A, {
          clockOut: T_LATER,
          updatedAt: T_LATER,
        }))));

      it('con isEdited=true → denegado', () =>
        assertFails(updateDoc(clockA1As(ALICE), {
          clockOut: T_LATER,
          isEdited: true,
          editedBy: 'employee',
          editedAt: Timestamp.now(),
        })));

      it('cambiar employeeId → denegado', () =>
        assertFails(updateDoc(clockA1As(ALICE), { employeeId: BOB })));

      it('cambiar companyId → denegado', () =>
        assertFails(updateDoc(clockA1As(ALICE), { companyId: COMPANY_B })));

      it('cambiar createdAt → denegado', () =>
        assertFails(updateDoc(clockA1As(ALICE), { createdAt: T_EARLIER })));

      it('cambiar id → denegado', () =>
        assertFails(updateDoc(clockA1As(ALICE), { id: 'otroId' })));

      it('un compañero NO actualiza un fichaje ajeno', () =>
        assertFails(updateDoc(clockA1As(BOB), { clockOut: T_LATER })));

      it('un empleado de otra empresa NO actualiza el fichaje', () =>
        assertFails(updateDoc(clockA1As(CAROL), { clockOut: T_LATER })));
    });

    describe('update por la empresa', () => {
      it('la empresa corrige un fichaje de su empresa con isEdited=true → ok', () =>
        assertSucceeds(updateDoc(clockA1As(COMPANY_A), {
          clockIn: T_EARLIER,
          clockOut: T_LATER,
          isEdited: true,
          editedBy: 'company',
          editedAt: Timestamp.now(),
          editReason: 'Olvido de fichaje',
          editedFields: ['clockIn', 'clockOut'],
          updatedAt: Timestamp.now(),
        })));

      it('la empresa NO cambia el employeeId del fichaje', () =>
        assertFails(updateDoc(clockA1As(COMPANY_A), { employeeId: BOB })));

      it('la empresa NO cambia el companyId del fichaje', () =>
        assertFails(updateDoc(clockA1As(COMPANY_A), { companyId: COMPANY_B })));

      it('la empresa NO cambia el createdAt del fichaje', () =>
        assertFails(updateDoc(clockA1As(COMPANY_A), { createdAt: T_EARLIER })));

      it('otra empresa NO actualiza el fichaje', () =>
        assertFails(updateDoc(clockA1As(COMPANY_B), { clockOut: T_LATER, isEdited: true })));
    });

    describe('delete', () => {
      it('delete denegado para el empleado dueño', () =>
        assertFails(deleteDoc(clockA1As(ALICE))));

      it('delete denegado para la empresa', () =>
        assertFails(deleteDoc(clockA1As(COMPANY_A))));
    });

    describe('lectura', () => {
      it('el dueño lee su fichaje', () =>
        assertSucceeds(getDoc(clockA1As(ALICE))));

      it('la empresa lee el fichaje', () =>
        assertSucceeds(getDoc(clockA1As(COMPANY_A))));

      it('un compañero de la misma empresa lee el fichaje (belongsToCompany)', () =>
        assertSucceeds(getDoc(clockA1As(BOB))));

      it('otra empresa NO lee el fichaje', () =>
        assertFails(getDoc(clockA1As(COMPANY_B))));

      it('un empleado de otra empresa NO lee el fichaje', () =>
        assertFails(getDoc(clockA1As(CAROL))));

      it('un usuario sin ficha NO lee el fichaje', () =>
        assertFails(getDoc(clockA1As(STRANGER))));
    });

    describe('queries de la app', () => {
      it('empleado: where employeeId == uid → ok', () =>
        assertSucceeds(getDocs(query(collection(asUser(ALICE), 'clockRecords'),
            where('employeeId', '==', ALICE)))));

      it('empleado: fichaje abierto (employeeId == uid, clockOut == null, orderBy, limit) → ok', () =>
        assertSucceeds(getDocs(query(collection(asUser(ALICE), 'clockRecords'),
            where('employeeId', '==', ALICE),
            where('clockOut', '==', null),
            orderBy('clockIn', 'desc'),
            limit(1)))));

      it('empleado: historial (employeeId == uid, orderBy clockIn desc) → ok', () =>
        assertSucceeds(getDocs(query(collection(asUser(ALICE), 'clockRecords'),
            where('employeeId', '==', ALICE),
            orderBy('clockIn', 'desc')))));

      it('empresa: where companyId == cid → ok', () =>
        assertSucceeds(getDocs(query(collection(asUser(COMPANY_A), 'clockRecords'),
            where('companyId', '==', COMPANY_A)))));

      it('empresa: companyId == cid + rango de clockIn → ok', () =>
        assertSucceeds(getDocs(query(collection(asUser(COMPANY_A), 'clockRecords'),
            where('companyId', '==', COMPANY_A),
            where('clockIn', '>=', T_EARLIER),
            where('clockIn', '<=', T_LATER)))));

      it('empresa: companyId == cid + employeeId + rango → ok', () =>
        assertSucceeds(getDocs(query(collection(asUser(COMPANY_A), 'clockRecords'),
            where('companyId', '==', COMPANY_A),
            where('employeeId', '==', ALICE),
            where('clockIn', '>=', T_EARLIER),
            where('clockIn', '<=', T_LATER)))));

      it('empleado de la empresa: where companyId == cid → ok (belongsToCompany)', () =>
        assertSucceeds(getDocs(query(collection(asUser(ALICE), 'clockRecords'),
            where('companyId', '==', COMPANY_A)))));

      it('empleado de OTRA empresa: where companyId == cid → denegada', () =>
        assertFails(getDocs(query(collection(asUser(CAROL), 'clockRecords'),
            where('companyId', '==', COMPANY_A)))));

      it('otra empresa: where companyId == cid → denegada', () =>
        assertFails(getDocs(query(collection(asUser(COMPANY_B), 'clockRecords'),
            where('companyId', '==', COMPANY_A)))));

      it('empleado: where employeeId == compañero (sin companyId) → denegada', () =>
        assertFails(getDocs(query(collection(asUser(ALICE), 'clockRecords'),
            where('employeeId', '==', BOB)))));

      it('query sin filtros → denegada', () =>
        assertFails(getDocs(collection(asUser(COMPANY_A), 'clockRecords'))));
    });
  });

  // =========================================================================
  describe('clockRecords/{id}/auditLog', () => {
    const logRef = (uid, logId) => doc(asUser(uid), 'clockRecords', CLOCK_A1, 'auditLog', logId);

    describe('create', () => {
      it('la empresa dueña crea con actorUid == uid y entryId correcto → ok', () =>
        assertSucceeds(setDoc(logRef(COMPANY_A, 'logCo'),
            auditDoc('logCo', CLOCK_A1, COMPANY_A, ALICE, COMPANY_A))));

      it('actorUid distinto al uid → denegado', () =>
        assertFails(setDoc(logRef(COMPANY_A, 'logFalso'),
            auditDoc('logFalso', CLOCK_A1, COMPANY_A, ALICE, ALICE))));

      it('entryId que no coincide con el fichaje padre → denegado', () =>
        assertFails(setDoc(logRef(COMPANY_A, 'logEntry'),
            auditDoc('logEntry', CLOCK_B1, COMPANY_A, ALICE, COMPANY_A))));

      it('sin campo at → denegado', () =>
        assertFails(setDoc(logRef(COMPANY_A, 'logSinAt'),
            auditDoc('logSinAt', CLOCK_A1, COMPANY_A, ALICE, COMPANY_A, { at: null }))));

      it('el empleado dueño del fichaje crea firmando como él → ok', () =>
        assertSucceeds(setDoc(logRef(ALICE, 'logEmp'),
            auditDoc('logEmp', CLOCK_A1, COMPANY_A, ALICE, ALICE, { action: 'created' }))));

      it('el empleado dueño NO puede firmar como la empresa', () =>
        assertFails(setDoc(logRef(ALICE, 'logEmpFalso'),
            auditDoc('logEmpFalso', CLOCK_A1, COMPANY_A, ALICE, COMPANY_A))));

      it('un compañero → denegado', () =>
        assertFails(setDoc(logRef(BOB, 'logBob'),
            auditDoc('logBob', CLOCK_A1, COMPANY_A, ALICE, BOB))));

      it('otra empresa → denegado', () =>
        assertFails(setDoc(logRef(COMPANY_B, 'logB'),
            auditDoc('logB', CLOCK_A1, COMPANY_A, ALICE, COMPANY_B))));

      it('auditLog de un fichaje inexistente → denegado', () =>
        assertFails(setDoc(doc(asUser(COMPANY_A), 'clockRecords', 'noExiste', 'auditLog', 'l'),
            auditDoc('l', 'noExiste', COMPANY_A, ALICE, COMPANY_A))));
    });

    describe('inmutabilidad', () => {
      it('update denegado para la empresa', () =>
        assertFails(updateDoc(logRef(COMPANY_A, LOG_A1), { reason: 'Reescrito' })));

      it('update denegado para el empleado', () =>
        assertFails(updateDoc(logRef(ALICE, LOG_A1), { reason: 'Reescrito' })));

      it('delete denegado para la empresa', () =>
        assertFails(deleteDoc(logRef(COMPANY_A, LOG_A1))));

      it('delete denegado para el empleado', () =>
        assertFails(deleteDoc(logRef(ALICE, LOG_A1))));
    });

    describe('lectura', () => {
      it('la empresa dueña lee el auditLog', () =>
        assertSucceeds(getDoc(logRef(COMPANY_A, LOG_A1))));

      it('el empleado dueño lee el auditLog', () =>
        assertSucceeds(getDoc(logRef(ALICE, LOG_A1))));

      it('un compañero de la misma empresa lee el auditLog', () =>
        assertSucceeds(getDoc(logRef(BOB, LOG_A1))));

      it('otra empresa NO lee el auditLog', () =>
        assertFails(getDoc(logRef(COMPANY_B, LOG_A1))));

      it('un empleado de otra empresa NO lee el auditLog', () =>
        assertFails(getDoc(logRef(CAROL, LOG_A1))));

      it('la empresa lista el auditLog (orderBy at) → ok', () =>
        assertSucceeds(getDocs(query(
            collection(asUser(COMPANY_A), 'clockRecords', CLOCK_A1, 'auditLog'),
            orderBy('at')))));

      it('otra empresa NO lista el auditLog', () =>
        assertFails(getDocs(query(
            collection(asUser(COMPANY_B), 'clockRecords', CLOCK_A1, 'auditLog'),
            orderBy('at')))));
    });
  });

  // =========================================================================
  describe('time_off_requests', () => {
    const reqAs = (uid, id) => doc(asUser(uid), 'time_off_requests', id);
    const transition = (uid, id, updates) =>
      setDoc(reqAs(uid, id), { ...updates, updatedAt: Timestamp.now() }, { merge: true });

    describe('create', () => {
      it('el empleado crea con status requested y su employeeId → ok', () =>
        assertSucceeds(addDoc(collection(asUser(ALICE), 'time_off_requests'),
            timeOffDoc(COMPANY_A, ALICE, 'requested'))));

      it('create con status approved → denegado', () =>
        assertFails(addDoc(collection(asUser(ALICE), 'time_off_requests'),
            timeOffDoc(COMPANY_A, ALICE, 'approved'))));

      it('create con status proposed → denegado', () =>
        assertFails(addDoc(collection(asUser(ALICE), 'time_off_requests'),
            timeOffDoc(COMPANY_A, ALICE, 'proposed'))));

      it('create con employeeId de otro → denegado', () =>
        assertFails(addDoc(collection(asUser(ALICE), 'time_off_requests'),
            timeOffDoc(COMPANY_A, BOB, 'requested'))));

      it('create con companyId ajeno → denegado', () =>
        assertFails(addDoc(collection(asUser(ALICE), 'time_off_requests'),
            timeOffDoc(COMPANY_B, ALICE, 'requested'))));

      it('la empresa NO crea solicitudes desde el cliente (solo el empleado)', () =>
        assertFails(addDoc(collection(asUser(COMPANY_A), 'time_off_requests'),
            timeOffDoc(COMPANY_A, ALICE, 'requested'))));

      it('un usuario sin ficha NO crea solicitudes', () =>
        assertFails(addDoc(collection(asUser(STRANGER), 'time_off_requests'),
            timeOffDoc(COMPANY_A, STRANGER, 'requested'))));
    });

    describe('transiciones del empleado', () => {
      it('requested → cancelled → ok', () =>
        assertSucceeds(transition(ALICE, REQ_ALICE_REQUESTED, {
          status: 'cancelled', decidedBy: ALICE,
        })));

      it('requested → approved → denegado (auto-aprobación)', () =>
        assertFails(transition(ALICE, REQ_ALICE_REQUESTED, {
          status: 'approved', decidedBy: ALICE,
        })));

      it('requested → rejected → denegado', () =>
        assertFails(transition(ALICE, REQ_ALICE_REQUESTED, { status: 'rejected' })));

      it('requested → proposed → denegado', () =>
        assertFails(transition(ALICE, REQ_ALICE_REQUESTED, {
          status: 'proposed', proposedDates: ['2026-12-01'],
        })));

      it('proposed → approved → ok (acepta la propuesta)', () =>
        assertSucceeds(transition(ALICE, REQ_ALICE_PROPOSED, {
          status: 'approved', decidedBy: ALICE,
        })));

      it('proposed → rejected → ok', () =>
        assertSucceeds(transition(ALICE, REQ_ALICE_PROPOSED, {
          status: 'rejected', decidedBy: ALICE,
        })));

      it('proposed → cancelled → ok', () =>
        assertSucceeds(transition(ALICE, REQ_ALICE_PROPOSED, {
          status: 'cancelled', decidedBy: ALICE,
        })));

      it('approved → cancelled → denegado', () =>
        assertFails(transition(ALICE, REQ_ALICE_APPROVED, { status: 'cancelled' })));

      it('approved → requested → denegado (no se reabre)', () =>
        assertFails(transition(ALICE, REQ_ALICE_APPROVED, { status: 'requested' })));

      it('el empleado NO cancela la solicitud de un compañero', () =>
        assertFails(transition(ALICE, REQ_BOB_REQUESTED, { status: 'cancelled' })));

      it('el empleado NO cambia el employeeId de su solicitud', () =>
        assertFails(transition(ALICE, REQ_ALICE_REQUESTED, {
          status: 'cancelled', employeeId: BOB,
        })));

      it('el empleado NO cambia el companyId de su solicitud', () =>
        assertFails(transition(ALICE, REQ_ALICE_REQUESTED, {
          status: 'cancelled', companyId: COMPANY_B,
        })));

      it('un empleado de otra empresa NO toca la solicitud', () =>
        assertFails(transition(CAROL, REQ_ALICE_REQUESTED, { status: 'cancelled' })));
    });

    describe('transiciones de la empresa', () => {
      it('requested → approved → ok', () =>
        assertSucceeds(transition(COMPANY_A, REQ_ALICE_REQUESTED, {
          status: 'approved', decidedBy: COMPANY_A,
        })));

      it('requested → rejected → ok', () =>
        assertSucceeds(transition(COMPANY_A, REQ_ALICE_REQUESTED, {
          status: 'rejected', decidedBy: COMPANY_A, companyNote: 'No hay cobertura',
        })));

      it('requested → proposed → ok', () =>
        assertSucceeds(transition(COMPANY_A, REQ_ALICE_REQUESTED, {
          status: 'proposed', proposedDates: ['2026-11-16'], companyNote: 'Mejor esta',
        })));

      it('approved → cancelled → ok (la empresa decide sin restricciones)', () =>
        assertSucceeds(transition(COMPANY_A, REQ_ALICE_APPROVED, {
          status: 'cancelled', decidedBy: COMPANY_A,
        })));

      it('la empresa NO cambia el employeeId', () =>
        assertFails(transition(COMPANY_A, REQ_ALICE_REQUESTED, {
          status: 'approved', employeeId: BOB,
        })));

      it('la empresa NO cambia el companyId', () =>
        assertFails(transition(COMPANY_A, REQ_ALICE_REQUESTED, {
          status: 'approved', companyId: COMPANY_B,
        })));

      it('otra empresa NO aprueba', () =>
        assertFails(transition(COMPANY_B, REQ_ALICE_REQUESTED, { status: 'approved' })));

      it('otra empresa NO rechaza', () =>
        assertFails(transition(COMPANY_B, REQ_ALICE_REQUESTED, { status: 'rejected' })));
    });

    describe('delete', () => {
      it('delete denegado para el empleado dueño', () =>
        assertFails(deleteDoc(reqAs(ALICE, REQ_ALICE_REQUESTED))));

      it('delete denegado para la empresa', () =>
        assertFails(deleteDoc(reqAs(COMPANY_A, REQ_ALICE_REQUESTED))));
    });

    describe('lectura', () => {
      it('la empresa lee las solicitudes de su empresa', () =>
        assertSucceeds(getDoc(reqAs(COMPANY_A, REQ_ALICE_REQUESTED))));

      it('el empleado dueño lee su solicitud', () =>
        assertSucceeds(getDoc(reqAs(ALICE, REQ_ALICE_REQUESTED))));

      it('un compañero lee la solicitud (solapamientos de equipo)', () =>
        assertSucceeds(getDoc(reqAs(BOB, REQ_ALICE_REQUESTED))));

      it('otra empresa NO lee', () =>
        assertFails(getDoc(reqAs(COMPANY_B, REQ_ALICE_REQUESTED))));

      it('un empleado de otra empresa NO lee', () =>
        assertFails(getDoc(reqAs(CAROL, REQ_ALICE_REQUESTED))));

      it('query del empleado (companyId + employeeId) → ok', () =>
        assertSucceeds(getDocs(query(collection(asUser(ALICE), 'time_off_requests'),
            where('companyId', '==', COMPANY_A),
            where('employeeId', '==', ALICE)))));

      it('query de la empresa (companyId) → ok', () =>
        assertSucceeds(getDocs(query(collection(asUser(COMPANY_A), 'time_off_requests'),
            where('companyId', '==', COMPANY_A)))));

      it('query de solapamientos (companyId + status in) por un empleado → ok', () =>
        assertSucceeds(getDocs(query(collection(asUser(ALICE), 'time_off_requests'),
            where('companyId', '==', COMPANY_A),
            where('status', 'in', ['approved', 'requested', 'proposed'])))));

      it('query de la empresa A por un empleado de B → denegada', () =>
        assertFails(getDocs(query(collection(asUser(CAROL), 'time_off_requests'),
            where('companyId', '==', COMPANY_A)))));
    });
  });

  // =========================================================================
  describe('conversations', () => {
    const convAs = (uid, id) => doc(asUser(uid), 'conversations', id);

    describe('lectura', () => {
      it('un miembro lee la conversación', () =>
        assertSucceeds(getDoc(convAs(ALICE, CONV_AB))));

      it('el otro miembro también la lee', () =>
        assertSucceeds(getDoc(convAs(BOB, CONV_AB))));

      it('un empleado de la empresa que NO es miembro NO lee un chat 1:1', () =>
        assertFails(getDoc(convAs(PEDRO, CONV_AB))));

      it('la empresa NO lee un chat 1:1 entre empleados del que no es miembro', () =>
        assertFails(getDoc(convAs(COMPANY_A, CONV_AB))));

      it('un empleado de otra empresa NO lee la conversación', () =>
        assertFails(getDoc(convAs(CAROL, CONV_AB))));

      it('un no miembro de la empresa lee el grupo (isGroup=true) de su empresa', () =>
        assertSucceeds(getDoc(convAs(PEDRO, GROUP_A))));

      it('un empleado de otra empresa NO lee el grupo', () =>
        assertFails(getDoc(convAs(CAROL, GROUP_A))));

      it('otra empresa NO lee el grupo', () =>
        assertFails(getDoc(convAs(COMPANY_B, GROUP_A))));

      it('query ensureDefaultGroup (companyId + isGroup + title) por un empleado → ok', () =>
        assertSucceeds(getDocs(query(collection(asUser(PEDRO), 'conversations'),
            where('companyId', '==', COMPANY_A),
            where('isGroup', '==', true),
            where('title', '==', 'Todos'),
            limit(1)))));

      it('query ensureDefaultGroup por la empresa → ok', () =>
        assertSucceeds(getDocs(query(collection(asUser(COMPANY_A), 'conversations'),
            where('companyId', '==', COMPANY_A),
            where('isGroup', '==', true),
            where('title', '==', 'Todos'),
            limit(1)))));

      it('query ensureDefaultGroup de A por un empleado de B → denegada', () =>
        assertFails(getDocs(query(collection(asUser(CAROL), 'conversations'),
            where('companyId', '==', COMPANY_A),
            where('isGroup', '==', true),
            where('title', '==', 'Todos'),
            limit(1)))));

      it('query de bandeja (companyId + memberIds array-contains uid) → ok', () =>
        assertSucceeds(getDocs(query(collection(asUser(ALICE), 'conversations'),
            where('companyId', '==', COMPANY_A),
            where('memberIds', 'array-contains', ALICE)))));

      it('query de bandeja de OTRO usuario (array-contains compañero) → denegada', () =>
        assertFails(getDocs(query(collection(asUser(ALICE), 'conversations'),
            where('companyId', '==', COMPANY_A),
            where('memberIds', 'array-contains', BOB)))));

      it('query de 1:1 existente (companyId + isGroup=false + array-contains uid) → ok', () =>
        assertSucceeds(getDocs(query(collection(asUser(ALICE), 'conversations'),
            where('companyId', '==', COMPANY_A),
            where('isGroup', '==', false),
            where('memberIds', 'array-contains', ALICE)))));
    });

    describe('create', () => {
      it('el creador es miembro y de la empresa → ok (empleado)', () =>
        assertSucceeds(addDoc(collection(asUser(ALICE), 'conversations'),
            conversationDoc(COMPANY_A, [ALICE, PEDRO]))));

      it('la empresa crea el grupo "Todos" siendo miembro → ok', () =>
        assertSucceeds(addDoc(collection(asUser(COMPANY_A), 'conversations'),
            conversationDoc(COMPANY_A, [COMPANY_A, ALICE, BOB], { isGroup: true, title: 'Todos' }))));

      it('crear sin ser miembro → denegado', () =>
        assertFails(addDoc(collection(asUser(ALICE), 'conversations'),
            conversationDoc(COMPANY_A, [BOB, PEDRO]))));

      it('crear con companyId ajeno → denegado', () =>
        assertFails(addDoc(collection(asUser(CAROL), 'conversations'),
            conversationDoc(COMPANY_A, [CAROL, ALICE]))));

      it('otra empresa NO crea conversaciones en la empresa A', () =>
        assertFails(addDoc(collection(asUser(COMPANY_B), 'conversations'),
            conversationDoc(COMPANY_A, [COMPANY_B, ALICE]))));

      it('un usuario sin ficha NO crea conversaciones', () =>
        assertFails(addDoc(collection(asUser(STRANGER), 'conversations'),
            conversationDoc(COMPANY_A, [STRANGER, ALICE]))));
    });

    describe('update', () => {
      it('un miembro actualiza metadatos (último mensaje, unreadCounts) sin tocar memberIds → ok', () =>
        assertSucceeds(updateDoc(convAs(ALICE, CONV_AB), {
          'lastMessageText': 'Hola',
          'lastMessageSenderId': ALICE,
          'lastMessageAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'unreadCounts.alice': 0,
          'unreadCounts.bob': increment(1),
        })));

      it('un miembro marca como leído (unreadCounts.uid = 0) → ok', () =>
        assertSucceeds(updateDoc(convAs(BOB, CONV_AB), { 'unreadCounts.bob': 0 })));

      it('un miembro reescribe memberIds con el mismo contenido → ok', () =>
        assertSucceeds(updateDoc(convAs(ALICE, CONV_AB), { memberIds: [ALICE, BOB] })));

      it('un miembro cambiando memberIds → denegado', () =>
        assertFails(updateDoc(convAs(ALICE, CONV_AB), { memberIds: [ALICE, BOB, PEDRO] })));

      it('un miembro cambiando companyId → denegado', () =>
        assertFails(updateDoc(convAs(ALICE, CONV_AB), { companyId: COMPANY_B })));

      it('la empresa cambia memberIds del grupo (alta de empleado) → ok', () =>
        assertSucceeds(updateDoc(convAs(COMPANY_A, GROUP_A), {
          'memberIds': [COMPANY_A, ALICE, BOB, PEDRO],
          'unreadCounts.pedro': 0,
        })));

      it('la empresa NO cambia el companyId de una conversación', () =>
        assertFails(updateDoc(convAs(COMPANY_A, GROUP_A), { companyId: COMPANY_B })));

      it('un no miembro de la empresa NO actualiza un chat 1:1', () =>
        assertFails(updateDoc(convAs(PEDRO, CONV_AB), { lastMessageText: 'Intruso' })));

      it('un no miembro NO actualiza el grupo aunque pueda leerlo', () =>
        assertFails(updateDoc(convAs(PEDRO, GROUP_A), { lastMessageText: 'Intruso' })));

      it('otra empresa NO actualiza', () =>
        assertFails(updateDoc(convAs(COMPANY_B, GROUP_A), { memberIds: [COMPANY_B] })));

      it('un empleado de otra empresa NO actualiza', () =>
        assertFails(updateDoc(convAs(CAROL, CONV_AB), { lastMessageText: 'Intrusa' })));
    });

    describe('delete', () => {
      it('delete denegado para un miembro', () =>
        assertFails(deleteDoc(convAs(ALICE, CONV_AB))));

      it('delete denegado para la empresa', () =>
        assertFails(deleteDoc(convAs(COMPANY_A, GROUP_A))));
    });

    describe('messages', () => {
      const msgsOf = (uid, convId) => collection(asUser(uid), 'conversations', convId, 'messages');
      const msg1As = (uid) => doc(asUser(uid), 'conversations', CONV_AB, 'messages', MSG_1);

      it('un miembro lee un mensaje', () =>
        assertSucceeds(getDoc(msg1As(BOB))));

      it('un miembro lista los mensajes (orderBy createdAt)', () =>
        assertSucceeds(getDocs(query(msgsOf(ALICE, CONV_AB), orderBy('createdAt')))));

      it('un no miembro NO lee los mensajes', () =>
        assertFails(getDoc(msg1As(PEDRO))));

      it('un no miembro NO lista los mensajes', () =>
        assertFails(getDocs(query(msgsOf(PEDRO, CONV_AB), orderBy('createdAt')))));

      it('la empresa NO lee mensajes de un chat 1:1 del que no es miembro', () =>
        assertFails(getDoc(msg1As(COMPANY_A))));

      it('un empleado de la empresa no miembro del grupo NO lista sus mensajes', () =>
        assertFails(getDocs(query(msgsOf(PEDRO, GROUP_A), orderBy('createdAt')))));

      it('create con senderId == uid por un miembro → ok', () =>
        assertSucceeds(addDoc(msgsOf(ALICE, CONV_AB), messageDoc(CONV_AB, ALICE))));

      it('la empresa envía en el grupo del que es miembro → ok', () =>
        assertSucceeds(addDoc(msgsOf(COMPANY_A, GROUP_A), messageDoc(GROUP_A, COMPANY_A))));

      it('senderId de otro usuario → denegado', () =>
        assertFails(addDoc(msgsOf(ALICE, CONV_AB), messageDoc(CONV_AB, BOB))));

      it('no miembro → denegado aunque firme como él mismo', () =>
        assertFails(addDoc(msgsOf(PEDRO, CONV_AB), messageDoc(CONV_AB, PEDRO))));

      it('no miembro del grupo → denegado aunque sea de la empresa', () =>
        assertFails(addDoc(msgsOf(PEDRO, GROUP_A), messageDoc(GROUP_A, PEDRO))));

      it('empleado de otra empresa → denegado', () =>
        assertFails(addDoc(msgsOf(CAROL, CONV_AB), messageDoc(CONV_AB, CAROL))));

      it('mensaje en una conversación inexistente → denegado', () =>
        assertFails(addDoc(msgsOf(ALICE, 'noExiste'), messageDoc('noExiste', ALICE))));

      it('update de mensaje denegado (autor)', () =>
        assertFails(updateDoc(msg1As(ALICE), { text: 'Editado' })));

      it('update de mensaje denegado (empresa)', () =>
        assertFails(updateDoc(msg1As(COMPANY_A), { text: 'Editado' })));

      it('delete de mensaje denegado (autor)', () =>
        assertFails(deleteDoc(msg1As(ALICE))));

      it('delete de mensaje denegado (empresa)', () =>
        assertFails(deleteDoc(msg1As(COMPANY_A))));
    });
  });

  // =========================================================================
  const scheduleCollections = [
    {
      name: 'company_shift_templates',
      seededA: TPL_A,
      seededB: TPL_B,
      make: (companyId) => templateDoc(companyId),
      edit: { name: 'Tarde', startTime: '16:00', endTime: '20:00' },
    },
    {
      name: 'employee_schedule_rules',
      seededA: RULE_A,
      seededB: RULE_B,
      make: (companyId) => ruleDoc(companyId, companyId === COMPANY_A ? ALICE : CAROL),
      edit: { weekdays: [1, 3, 5] },
    },
  ];

  for (const col of scheduleCollections) {
    describe(col.name, () => {
      const refAs = (uid, id) => doc(asUser(uid), col.name, id);

      it('la empresa crea los suyos', () =>
        assertSucceeds(setDoc(refAs(COMPANY_A, 'nuevo'), col.make(COMPANY_A))));

      it('la empresa crea con id autogenerado (add)', () =>
        assertSucceeds(addDoc(collection(asUser(COMPANY_A), col.name), col.make(COMPANY_A))));

      it('la empresa edita los suyos', () =>
        assertSucceeds(updateDoc(refAs(COMPANY_A, col.seededA), {
          ...col.edit, updatedAt: Timestamp.now(),
        })));

      it('la empresa edita los suyos con set(merge)', () =>
        assertSucceeds(setDoc(refAs(COMPANY_A, col.seededA), {
          ...col.edit, updatedAt: Timestamp.now(),
        }, { merge: true })));

      it('la empresa desactiva (active=false) los suyos', () =>
        assertSucceeds(updateDoc(refAs(COMPANY_A, col.seededA), { active: false })));

      it('la empresa borra los suyos', () =>
        assertSucceeds(deleteDoc(refAs(COMPANY_A, col.seededA))));

      it('la empresa NO crea con companyId ajeno', () =>
        assertFails(setDoc(refAs(COMPANY_A, 'ajeno'), col.make(COMPANY_B))));

      it('la empresa lee los suyos', () =>
        assertSucceeds(getDoc(refAs(COMPANY_A, col.seededA))));

      it('el empleado lee los de su empresa', () =>
        assertSucceeds(getDoc(refAs(ALICE, col.seededA))));

      it('el empleado lista los de su empresa (companyId + active)', () =>
        assertSucceeds(getDocs(query(collection(asUser(ALICE), col.name),
            where('companyId', '==', COMPANY_A),
            where('active', '==', true)))));

      it('el empleado NO crea', () =>
        assertFails(setDoc(refAs(ALICE, 'empleado'), col.make(COMPANY_A))));

      it('el empleado NO edita', () =>
        assertFails(updateDoc(refAs(ALICE, col.seededA), col.edit)));

      it('el empleado NO borra', () =>
        assertFails(deleteDoc(refAs(ALICE, col.seededA))));

      it('otra empresa NO lee', () =>
        assertFails(getDoc(refAs(COMPANY_B, col.seededA))));

      it('otra empresa NO lista los de A', () =>
        assertFails(getDocs(query(collection(asUser(COMPANY_B), col.name),
            where('companyId', '==', COMPANY_A)))));

      it('otra empresa NO edita', () =>
        assertFails(updateDoc(refAs(COMPANY_B, col.seededA), col.edit)));

      it('otra empresa NO borra', () =>
        assertFails(deleteDoc(refAs(COMPANY_B, col.seededA))));

      it('un empleado de otra empresa NO lee', () =>
        assertFails(getDoc(refAs(CAROL, col.seededA))));

      it('un empleado de otra empresa NO lista los de A', () =>
        assertFails(getDocs(query(collection(asUser(CAROL), col.name),
            where('companyId', '==', COMPANY_A)))));
    });
  }

  // =========================================================================
  describe('employee_schedule_months', () => {
    const COL = 'employee_schedule_months';
    const aliceMonth = monthId(COMPANY_A, ALICE, MONTH);
    const bobMonth = monthId(COMPANY_A, BOB, MONTH);
    const refAs = (uid, id) => doc(asUser(uid), COL, id);
    const override = { [`${MONTH}-12`]: { type: 'vacation' } };

    it('la empresa crea el mes de un empleado', () =>
      assertSucceeds(setDoc(refAs(COMPANY_A, monthId(COMPANY_A, ALICE, MONTH_NEXT)),
          monthDoc(COMPANY_A, ALICE, MONTH_NEXT), { merge: true })));

    it('la empresa edita el mes de un empleado (merge de entries)', () =>
      assertSucceeds(setDoc(refAs(COMPANY_A, aliceMonth), {
        entries: override, updatedAt: Timestamp.now(),
      }, { merge: true })));

    it('la empresa borra una key de entries (deleteField)', () =>
      assertSucceeds(setDoc(refAs(COMPANY_A, aliceMonth), {
        entries: { [`${MONTH}-05`]: deleteField() }, updatedAt: Timestamp.now(),
      }, { merge: true })));

    it('la empresa NO crea con companyId ajeno', () =>
      assertFails(setDoc(refAs(COMPANY_A, monthId(COMPANY_B, CAROL, MONTH_NEXT)),
          monthDoc(COMPANY_B, CAROL, MONTH_NEXT), { merge: true })));

    it('el empleado crea el SUYO (employeeId == uid) en su empresa', () =>
      assertSucceeds(setDoc(refAs(ALICE, monthId(COMPANY_A, ALICE, MONTH_NEXT)),
          monthDoc(COMPANY_A, ALICE, MONTH_NEXT), { merge: true })));

    it('el empleado edita el SUYO', () =>
      assertSucceeds(setDoc(refAs(ALICE, aliceMonth), {
        entries: override, updatedAt: Timestamp.now(),
      }, { merge: true })));

    it('el empleado NO edita el de un compañero', () =>
      assertFails(setDoc(refAs(ALICE, bobMonth), {
        entries: override, updatedAt: Timestamp.now(),
      }, { merge: true })));

    it('el empleado NO crea el de un compañero', () =>
      assertFails(setDoc(refAs(ALICE, monthId(COMPANY_A, BOB, MONTH_NEXT)),
          monthDoc(COMPANY_A, BOB, MONTH_NEXT), { merge: true })));

    it('el empleado NO crea con companyId ajeno', () =>
      assertFails(setDoc(refAs(ALICE, monthId(COMPANY_B, ALICE, MONTH_NEXT)),
          monthDoc(COMPANY_B, ALICE, MONTH_NEXT), { merge: true })));

    it('un usuario sin ficha NO crea', () =>
      assertFails(setDoc(refAs(STRANGER, monthId(COMPANY_A, STRANGER, MONTH_NEXT)),
          monthDoc(COMPANY_A, STRANGER, MONTH_NEXT), { merge: true })));

    it('otra empresa NO edita', () =>
      assertFails(setDoc(refAs(COMPANY_B, aliceMonth), { entries: override }, { merge: true })));

    it('la empresa borra el mes', () =>
      assertSucceeds(deleteDoc(refAs(COMPANY_A, aliceMonth))));

    it('el empleado borra el SUYO', () =>
      assertSucceeds(deleteDoc(refAs(ALICE, aliceMonth))));

    it('el empleado NO borra el de un compañero', () =>
      assertFails(deleteDoc(refAs(ALICE, bobMonth))));

    it('la empresa lee', () =>
      assertSucceeds(getDoc(refAs(COMPANY_A, aliceMonth))));

    it('el empleado lee el suyo', () =>
      assertSucceeds(getDoc(refAs(ALICE, aliceMonth))));

    it('un compañero lee (calendario de equipo)', () =>
      assertSucceeds(getDoc(refAs(BOB, aliceMonth))));

    it('otra empresa NO lee', () =>
      assertFails(getDoc(refAs(COMPANY_B, aliceMonth))));

    it('un empleado de otra empresa NO lee', () =>
      assertFails(getDoc(refAs(CAROL, aliceMonth))));

    it('query de la empresa (companyId + month + employeeId in) → ok', () =>
      assertSucceeds(getDocs(query(collection(asUser(COMPANY_A), COL),
          where('companyId', '==', COMPANY_A),
          where('month', '==', MONTH),
          where('employeeId', 'in', [ALICE, BOB])))));

    it('query del empleado (companyId + employeeId) → ok', () =>
      assertSucceeds(getDocs(query(collection(asUser(ALICE), COL),
          where('companyId', '==', COMPANY_A),
          where('employeeId', '==', ALICE)))));

    it('query de A por un empleado de B → denegada', () =>
      assertFails(getDocs(query(collection(asUser(CAROL), COL),
          where('companyId', '==', COMPANY_A)))));
  });

  // =========================================================================
  describe('user_fcm_tokens', () => {
    const rootAs = (uid, owner) => doc(asUser(uid), 'user_fcm_tokens', owner);
    const tokenAs = (uid, owner, token) => doc(asUser(uid), 'user_fcm_tokens', owner, 'tokens', token);

    it('el dueño lee su doc raíz', () =>
      assertSucceeds(getDoc(rootAs(ALICE, ALICE))));

    it('el dueño escribe su doc raíz', () =>
      assertSucceeds(setDoc(rootAs(ALICE, ALICE), { updatedAt: Timestamp.now() }, { merge: true })));

    it('el dueño registra un token', () =>
      assertSucceeds(setDoc(tokenAs(ALICE, ALICE, 'nuevoToken'), {
        token: 'nuevoToken', platform: 'android', updatedAt: Timestamp.now(),
      })));

    it('el dueño lee un token', () =>
      assertSucceeds(getDoc(tokenAs(ALICE, ALICE, TOKEN_1))));

    it('el dueño lista sus tokens', () =>
      assertSucceeds(getDocs(collection(asUser(ALICE), 'user_fcm_tokens', ALICE, 'tokens'))));

    it('el dueño borra un token', () =>
      assertSucceeds(deleteDoc(tokenAs(ALICE, ALICE, TOKEN_1))));

    it('la empresa crea su propio doc de tokens', () =>
      assertSucceeds(setDoc(tokenAs(COMPANY_A, COMPANY_A, 'tokCo'), { token: 'tokCo' })));

    it('otro usuario NO lee el doc raíz', () =>
      assertFails(getDoc(rootAs(BOB, ALICE))));

    it('otro usuario NO escribe el doc raíz', () =>
      assertFails(setDoc(rootAs(BOB, ALICE), { updatedAt: Timestamp.now() }, { merge: true })));

    it('otro usuario NO lee un token', () =>
      assertFails(getDoc(tokenAs(BOB, ALICE, TOKEN_1))));

    it('otro usuario NO escribe un token', () =>
      assertFails(setDoc(tokenAs(BOB, ALICE, 'malicioso'), { token: 'malicioso' })));

    it('otro usuario NO borra un token', () =>
      assertFails(deleteDoc(tokenAs(BOB, ALICE, TOKEN_1))));

    it('la empresa NO lee los tokens de su empleado', () =>
      assertFails(getDoc(tokenAs(COMPANY_A, ALICE, TOKEN_1))));

    it('la empresa NO lista los tokens de su empleado', () =>
      assertFails(getDocs(collection(asUser(COMPANY_A), 'user_fcm_tokens', ALICE, 'tokens'))));
  });

  // =========================================================================
  describe('colecciones solo backend y no contempladas', () => {
    const cases = [
      { col: 'mail', id: 'mail1', data: { to: 'x@y.z', message: { subject: 'S', text: 'T' } } },
      { col: '_appleEvents', id: 'evt1', data: { notificationUUID: 'uuid-2' } },
      { col: 'random', id: 'x', data: { foo: 'baz' } },
    ];

    for (const c of cases) {
      describe(`${c.col}/{docId}`, () => {
        it('lectura denegada para la empresa', () =>
          assertFails(getDoc(doc(asUser(COMPANY_A), c.col, c.id))));

        it('lectura denegada para un empleado', () =>
          assertFails(getDoc(doc(asUser(ALICE), c.col, c.id))));

        it('listado denegado para la empresa', () =>
          assertFails(getDocs(collection(asUser(COMPANY_A), c.col))));

        it('create denegado para la empresa', () =>
          assertFails(setDoc(doc(asUser(COMPANY_A), c.col, 'nuevo'), c.data)));

        it('create (add) denegado para un empleado', () =>
          assertFails(addDoc(collection(asUser(ALICE), c.col), c.data)));

        it('update denegado para la empresa', () =>
          assertFails(updateDoc(doc(asUser(COMPANY_A), c.col, c.id), c.data)));

        it('delete denegado para la empresa', () =>
          assertFails(deleteDoc(doc(asUser(COMPANY_A), c.col, c.id))));

        it('todo denegado sin autenticar', async () => {
          await assertFails(getDoc(doc(asAnon(), c.col, c.id)));
          await assertFails(setDoc(doc(asAnon(), c.col, 'anon'), c.data));
        });
      });
    }

    it('subcolección arbitraria bajo una empresa → denegada', () =>
      assertFails(setDoc(doc(asUser(COMPANY_A), 'companies', COMPANY_A, 'notas', 'n1'), {
        texto: 'hola',
      })));

    it('subcolección arbitraria bajo un empleado → denegada incluso al dueño', () =>
      assertFails(setDoc(doc(asUser(ALICE), 'employees', ALICE, 'notas', 'n1'), {
        texto: 'hola',
      })));
  });

  // =========================================================================
  describe('clockReports', () => {
    const repAs = (uid, id) => doc(asUser(uid), 'clockReports', id);

    it('la empresa lee los reportes de su empresa', () =>
      assertSucceeds(getDoc(repAs(COMPANY_A, REPORT_A))));

    it('el empleado de la empresa lee', () =>
      assertSucceeds(getDoc(repAs(ALICE, REPORT_A))));

    it('un compañero lee (misma empresa)', () =>
      assertSucceeds(getDoc(repAs(BOB, REPORT_A))));

    it('otra empresa NO lee', () =>
      assertFails(getDoc(repAs(COMPANY_B, REPORT_A))));

    it('un empleado de otra empresa NO lee', () =>
      assertFails(getDoc(repAs(CAROL, REPORT_A))));

    it('un usuario sin ficha NO lee', () =>
      assertFails(getDoc(repAs(STRANGER, REPORT_A))));

    it('escritura (create) denegada para la empresa', () =>
      assertFails(setDoc(repAs(COMPANY_A, 'nuevo'), reportDoc(COMPANY_A, ALICE))));

    it('escritura (update) denegada para la empresa', () =>
      assertFails(updateDoc(repAs(COMPANY_A, REPORT_A), { periodEnd: '2026-10-31' })));

    it('escritura denegada para el empleado', () =>
      assertFails(setDoc(repAs(ALICE, 'nuevoEmp'), reportDoc(COMPANY_A, ALICE))));

    it('delete denegado para la empresa', () =>
      assertFails(deleteDoc(repAs(COMPANY_A, REPORT_A))));

    it('query del empleado (companyId + employeeId) → ok', () =>
      assertSucceeds(getDocs(query(collection(asUser(ALICE), 'clockReports'),
          where('companyId', '==', COMPANY_A),
          where('employeeId', '==', ALICE)))));

    it('query de la empresa (companyId + rango periodStart) → ok', () =>
      assertSucceeds(getDocs(query(collection(asUser(COMPANY_A), 'clockReports'),
          where('companyId', '==', COMPANY_A),
          where('periodStart', '>=', '2026-01-01'),
          where('periodStart', '<', '2027-01-01')))));

    it('query de A por un empleado de B → denegada', () =>
      assertFails(getDocs(query(collection(asUser(CAROL), 'clockReports'),
          where('companyId', '==', COMPANY_A)))));
  });

  // =========================================================================
  // Casos de endurecimiento: escenarios que las reglas DEBERÍAN denegar según
  // los principios declarados en firestore.rules (inmutabilidad del registro
  // horario, aislamiento entre empresas, condiciones laborales fijadas por la
  // empresa). Si alguno falla, es un hallazgo sobre las reglas, no sobre el
  // test: NO se ajusta la expectativa para ponerlo en verde.
  // =========================================================================
  describe('Lecturas de documentos inexistentes (resource == null)', () => {
    it('employee_schedule_months: el empleado puede hacer get() de SU mes aunque no exista', () =>
      assertSucceeds(getDoc(doc(asUser(ALICE), 'employee_schedule_months', monthId(COMPANY_A, ALICE, '2031-01')))));
    it('employee_schedule_months: la empresa puede hacer get() de un mes inexistente de su empresa', () =>
      assertSucceeds(getDoc(doc(asUser(COMPANY_A), 'employee_schedule_months', monthId(COMPANY_A, ALICE, '2031-01')))));
    it('employee_schedule_months: un empleado de OTRA empresa NO puede hacer get() de un mes inexistente ajeno', () =>
      assertFails(getDoc(doc(asUser(CAROL), 'employee_schedule_months', monthId(COMPANY_A, ALICE, '2031-01')))));
    it('employees: un usuario puede hacer get() de employees/{su uid} aunque no exista (login cruzado de farmacia)', () =>
      assertSucceeds(getDoc(doc(asUser(COMPANY_A), 'employees', COMPANY_A))));
    it('employees: get() de un doc inexistente de otro uid sigue denegado', () =>
      assertFails(getDoc(doc(asUser(ALICE), 'employees', 'no-existe'))));
  });

  describe('Endurecimiento adicional (hallazgos potenciales sobre las reglas)', () => {
    it('clockRecords: el empleado NO puede crear un fichaje a nombre de un compañero', () =>
      // La regla de create solo exige belongsToCompany(companyId) e isEdited=false,
      // no comprueba employeeId == uid para empleados.
      assertFails(setDoc(doc(asUser(ALICE), 'clockRecords', 'fichajeDeBob'),
          clockDoc('fichajeDeBob', BOB, COMPANY_A))));

    it('clockRecords: el empleado NO puede alterar clockIn de su fichaje sin marcarlo como editado', () =>
      // El update del empleado solo exige isEdited=false y campos de origen intactos;
      // clockIn puede reescribirse sin traza (ni isEdited ni auditLog).
      assertFails(updateDoc(doc(asUser(ALICE), 'clockRecords', CLOCK_A1), {
        clockIn: T_EARLIER,
        updatedAt: Timestamp.now(),
      })));

    it('employees: el empleado NO puede modificar su createdAt (base del devengo de vacaciones)', () =>
      // earnedByTime() usa employee.createdAt como fecha de alta; la regla no lo protege.
      assertFails(updateDoc(doc(asUser(ALICE), 'employees', ALICE), {
        createdAt: Timestamp.fromDate(new Date('2015-01-01T00:00:00Z')),
      })));

    it('employees: el empleado NO puede modificar su hireDate', () =>
      // Documentado en las reglas como no comparado (Timestamp vs ISO en el cliente).
      assertFails(updateDoc(doc(asUser(ALICE), 'employees', ALICE), {
        hireDate: Timestamp.fromDate(new Date('2015-01-01T00:00:00Z')),
      })));

    it('time_off_requests: el empleado NO puede aceptar una propuesta alterando dates/proposedDates', () =>
      // proposed → approved está permitido, pero la regla no exige que dates y
      // proposedDates queden intactos: el empleado podría "aprobarse" otras fechas.
      assertFails(setDoc(doc(asUser(ALICE), 'time_off_requests', REQ_ALICE_PROPOSED), {
        status: 'approved',
        decidedBy: ALICE,
        proposedDates: [],
        dates: ['2026-12-24', '2026-12-28', '2026-12-29', '2026-12-30', '2026-12-31'],
        updatedAt: Timestamp.now(),
      }, { merge: true })));

    it('employee_schedule_months: el empleado NO puede reasignar employeeId/companyId de su mes', () =>
      // El update del empleado solo valida el doc existente; los campos nuevos no se fijan.
      assertFails(setDoc(doc(asUser(ALICE), 'employee_schedule_months', monthId(COMPANY_A, ALICE, MONTH)), {
        employeeId: BOB,
        updatedAt: Timestamp.now(),
      }, { merge: true })));

    it('company_shift_templates: la empresa NO puede reasignar su plantilla a otra empresa', () =>
      // update/delete solo validan isCompany(existingCompanyId()); companyId puede cambiarse.
      assertFails(updateDoc(doc(asUser(COMPANY_A), 'company_shift_templates', TPL_A), {
        companyId: COMPANY_B,
      })));

    it('employee_schedule_rules: la empresa NO puede inyectar una regla en otra empresa (companyId/employeeId)', () =>
      assertFails(updateDoc(doc(asUser(COMPANY_A), 'employee_schedule_rules', RULE_A), {
        companyId: COMPANY_B,
        employeeId: CAROL,
      })));

    it('employee_schedule_months: la empresa NO puede reasignar un mes a otra empresa', () =>
      assertFails(setDoc(doc(asUser(COMPANY_A), 'employee_schedule_months', monthId(COMPANY_A, ALICE, MONTH)), {
        companyId: COMPANY_B,
        employeeId: CAROL,
      }, { merge: true })));
  });
});
