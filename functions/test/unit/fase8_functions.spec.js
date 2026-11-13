/* eslint-disable */
// Fase 8: regresiones de Cloud Functions (sin Firestore).
const assert = require('assert');
const { execFileSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const ROOT = path.join(__dirname, '..', '..');

describe('Zona horaria del runtime (CAND-001: PDF del registro horario en UTC)', () => {
  const run = (code) => execFileSync(process.execPath, ['-e', code], { cwd: ROOT, env: { ...process.env, TZ: 'UTC' } }).toString().trim();
  it('la primera sentencia de index.js fija TZ=Europe/Madrid y date-fns formatea en hora de Madrid', () => {
    const src = fs.readFileSync(path.join(ROOT, 'index.js'), 'utf8');
    const firstStmt = src.split('\n').find((l) => l.trim().startsWith('process.env.TZ'));
    assert.ok(firstStmt, 'index.js debe fijar process.env.TZ');
    assert.ok(src.indexOf(firstStmt) < src.indexOf('require('), 'TZ debe fijarse antes de cualquier require');
    const out = JSON.parse(run(`
      delete process.env.TZ; ${firstStmt}
      const { format } = require('date-fns');
      console.log(JSON.stringify({ tz: process.env.TZ, hours: new Date('2026-10-20T07:00:00Z').getHours(),
        fmt: format(new Date('2026-10-20T07:00:00Z'), 'HH:mm'), day: format(new Date('2026-10-31T23:30:00Z'), 'yyyy-MM-dd') }));`));
    assert.strictEqual(out.tz, 'Europe/Madrid');
    assert.strictEqual(out.hours, 9, '07:00Z debe ser 09:00 en Madrid (CEST)');
    assert.strictEqual(out.fmt, '09:00');
    assert.strictEqual(out.day, '2026-11-01', '23:30Z del 31/10 ya es 1 de noviembre en Madrid');
  });
  it('sin fijar TZ el mismo instante se formatea como 07:00 (el fallo original)', () => {
    assert.strictEqual(run("const {format}=require('date-fns');console.log(format(new Date('2026-10-20T07:00:00Z'),'HH:mm'))"), '07:00');
  });
});

describe('googlePlayNotifications: CANCELED con periodo pagado vigente', () => {
  const { _mapGoogleState: map, _isStillPaid: isStillPaid } = require('../../src/iap/googlePlayNotifications');
  it('mapea los estados conocidos y desconocidos', () => {
    assert.strictEqual(map('SUBSCRIPTION_STATE_ACTIVE'), 'active');
    assert.strictEqual(map('SUBSCRIPTION_STATE_CANCELED'), 'canceled');
    assert.strictEqual(map('SUBSCRIPTION_STATE_EXPIRED'), 'expired');
    assert.strictEqual(map('LO_QUE_SEA'), 'none');
  });
  it('isStillPaid: expiryTime futuro → sigue pagado; pasado o ausente → no', () => {
    const now = Date.parse('2026-10-20T10:00:00Z');
    const sub = (exp) => ({ lineItems: [{ productId: 'plan_5_employees', expiryTime: exp }] });
    assert.strictEqual(isStillPaid(sub('2026-11-01T10:00:00Z'), 'plan_5_employees', now), true);
    assert.strictEqual(isStillPaid(sub('2026-10-01T10:00:00Z'), 'plan_5_employees', now), false);
    assert.strictEqual(isStillPaid({ lineItems: [] }, 'plan_5_employees', now), false);
    assert.strictEqual(isStillPaid(null, 'plan_5_employees', now), false);
  });
});

describe('Purga en cascada: el uid sale del id del documento, no de un campo del cliente', () => {
  it('onEmployeeStatusChanged ya no lee afterData.authUid/afterData.uid para purgar', () => {
    const src = fs.readFileSync(path.join(ROOT, 'src', 'employees', 'onEmployeeStatusChanged.js'), 'utf8');
    assert.ok(src.includes('const uid = event.params.employeeId;'));
    assert.ok(!/afterData\.authUid \|\| afterData\.uid \|\|/.test(src));
  });
  it('deleteCompanyData usa emp.id y la cascada borra los informes PDF de Storage', () => {
    const src = fs.readFileSync(path.join(ROOT, 'src', 'helpers', 'cascadeDelete.js'), 'utf8');
    assert.ok(!src.includes("emp.data()?.uid || emp.id"));
    assert.ok(src.includes('deleteStoragePrefix(`reports/${companyId}/${employeeUid}`)'));
    assert.ok(src.includes('deleteStoragePrefix(`reports/${companyId}`)'));
  });
  it('reportsOnClockRecordWrite no regenera informes de un empleado en purga', () => {
    const src = fs.readFileSync(path.join(ROOT, 'src', 'reports', 'monthlyReports.js'), 'utf8');
    assert.ok(src.includes("employee.accountStatus === 'deleted'"));
  });
});
