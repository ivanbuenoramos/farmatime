// Catálogo de planes IAP.
// Cada plan es un producto de suscripción PROPIO en ambas tiendas (no un base
// plan dentro de una suscripción única). Los product IDs de Google Play solo
// admiten minúsculas, dígitos, _ y . (los guiones solo valen en base plan
// IDs), así que el ID con _ es el mismo en las dos plataformas.
// El total de plazas INCLUYE la plaza gratuita (la empresa).
const PLAN_LIST = [
  { ios: 'plan_5_employees', android: 'plan_5_employees', totalSeats: 5, priceCents: 399 },
  { ios: 'plan_10_employees', android: 'plan_10_employees', totalSeats: 10, priceCents: 899 },
  { ios: 'plan_20_employees', android: 'plan_20_employees', totalSeats: 20, priceCents: 1799 },
];

const PLANS = {};
for (const p of PLAN_LIST) {
  const data = { totalSeats: p.totalSeats, priceCents: p.priceCents };
  PLANS[p.ios] = data;
  PLANS[p.android] = data;
}

function getPlan(productId) {
  return PLANS[productId] || null;
}

function isKnownProduct(productId) {
  return Object.prototype.hasOwnProperty.call(PLANS, productId);
}

function listProductIds() {
  return Object.keys(PLANS);
}

function listIosProductIds() {
  return PLAN_LIST.map((p) => p.ios);
}

function listAndroidProductIds() {
  return PLAN_LIST.map((p) => p.android);
}

module.exports = {
  PLANS,
  getPlan,
  isKnownProduct,
  listProductIds,
  listIosProductIds,
  listAndroidProductIds,
};
