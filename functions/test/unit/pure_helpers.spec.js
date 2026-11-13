/* eslint-disable */
// Pruebas unitarias de lógica pura de Cloud Functions (sin Firestore).
const assert = require('assert');
const { toMinutes, ymdMadrid, weekdayMadrid } = require('../../src/notifications/scheduleResolver');
const { SEAT_OCCUPYING, PROMOTABLE, occupiesSeat, isPromotable } = require('../../src/helpers/seatPolicy');
const { getPlan, isKnownProduct, listIosProductIds, listAndroidProductIds } = require('../../src/iap/helpers/planCatalog');
const { GRACE_DAYS, GRACE_MS } = require('../../src/helpers/billingEmployees');

describe('scheduleResolver.toMinutes', () => {
  it('convierte HHmm y HH:mm a minutos', () => {
    assert.strictEqual(toMinutes('0900'), 540);
    assert.strictEqual(toMinutes('09:30'), 570);
    assert.strictEqual(toMinutes('2359'), 23 * 60 + 59);
    assert.strictEqual(toMinutes('0000'), 0);
  });
  it('rechaza valores inválidos', () => {
    assert.strictEqual(toMinutes(null), null);
    assert.strictEqual(toMinutes(''), null);
    assert.strictEqual(toMinutes('9:00'), null, 'tres dígitos no es un HHmm válido');
    assert.strictEqual(toMinutes('2400'), null);
    assert.strictEqual(toMinutes('1260'), null);
    assert.strictEqual(toMinutes('abcd'), null);
  });
});

describe('scheduleResolver zona Europe/Madrid', () => {
  it('ymdMadrid usa la fecha local de Madrid, no UTC (madrugada)', () => {
    // 23:30 UTC del 10 de julio = 01:30 del 11 de julio en Madrid (CEST, UTC+2).
    assert.strictEqual(ymdMadrid(new Date('2026-07-10T23:30:00Z')), '2026-07-11');
    // 23:30 UTC del 10 de enero = 00:30 del 11 de enero en Madrid (CET, UTC+1).
    assert.strictEqual(ymdMadrid(new Date('2026-01-10T23:30:00Z')), '2026-01-11');
    // 22:30 UTC en invierno sigue siendo el mismo día en Madrid.
    assert.strictEqual(ymdMadrid(new Date('2026-01-10T22:30:00Z')), '2026-01-10');
  });
  it('weekdayMadrid devuelve 1..7 (Lun..Dom) coherente con la fecha local', () => {
    // 2026-10-17 es sábado (6); a las 23:30Z ya es domingo (7) en Madrid.
    assert.strictEqual(weekdayMadrid(new Date('2026-10-17T12:00:00Z')), 6);
    assert.strictEqual(weekdayMadrid(new Date('2026-10-17T23:30:00Z')), 7);
    assert.strictEqual(weekdayMadrid(new Date('2026-10-19T08:00:00Z')), 1);
  });
  it('cambio de hora (DST): el día en que se adelanta/atrasa el reloj se resuelve bien', () => {
    // 2026-03-29 (último domingo de marzo) 00:30 UTC = 01:30 CET → mismo día.
    assert.strictEqual(ymdMadrid(new Date('2026-03-29T00:30:00Z')), '2026-03-29');
    // 2026-10-25 (último domingo de octubre) 23:30 UTC = 00:30 CET del 26.
    assert.strictEqual(ymdMadrid(new Date('2026-10-25T23:30:00Z')), '2026-10-26');
  });
});

describe('seatPolicy', () => {
  it('deleted nunca ocupa plaza; el resto sí', () => {
    assert.strictEqual(occupiesSeat('deleted'), false);
    for (const s of ['pending', 'active', 'inactive', 'disabled']) assert.strictEqual(occupiesSeat(s), true, s);
    assert.strictEqual(occupiesSeat(undefined), false);
  });
  it('pending no es promocionable; active/inactive/disabled sí', () => {
    assert.strictEqual(isPromotable('pending'), false);
    for (const s of ['active', 'inactive', 'disabled']) assert.strictEqual(isPromotable(s), true, s);
    assert.ok([...PROMOTABLE].every((s) => SEAT_OCCUPYING.has(s)), 'todo promocionable ocupa plaza');
  });
});

describe('planCatalog', () => {
  it('los IDs de producto coinciden en iOS y Android y con el cliente (lib/core/iap/iap_plans.dart)', () => {
    assert.deepStrictEqual(listIosProductIds(), ['plan_5_employees', 'plan_10_employees', 'plan_20_employees']);
    assert.deepStrictEqual(listAndroidProductIds(), listIosProductIds());
    // Google Play solo admite [a-z0-9_.]
    for (const id of listAndroidProductIds()) assert.match(id, /^[a-z0-9_.]+$/);
  });
  it('getPlan devuelve plazas totales (incluida la gratuita) y null para desconocidos', () => {
    assert.strictEqual(getPlan('plan_5_employees').totalSeats, 5);
    assert.strictEqual(getPlan('plan_10_employees').totalSeats, 10);
    assert.strictEqual(getPlan('plan_20_employees').totalSeats, 20);
    assert.strictEqual(getPlan('plan_2_employees'), null, 'producto legacy del StoreKit config local no existe en el catálogo');
    assert.strictEqual(isKnownProduct('toString'), false, 'no debe confundirse con propiedades del prototipo');
  });
});

describe('billingEmployees constantes', () => {
  it('la gracia in-app es de 30 días y coincide con CompanyModel.gracePeriodDays del cliente', () => {
    assert.strictEqual(GRACE_DAYS, 30);
    assert.strictEqual(GRACE_MS, 30 * 24 * 60 * 60 * 1000);
  });
});
