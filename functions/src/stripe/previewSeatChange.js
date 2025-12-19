const { onCall, HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');

const { db } = require('../config/firebase');
const { assertAuth, assertCompanyAccount } = require('../helpers/assertions');
const { getStripe } = require('../config/stripe');

function getSeatItemFromSub({ sub, PRICE_ID }) {
  const items = sub?.items?.data || [];
  return (
    (PRICE_ID ? items.find((i) => i?.price?.id === PRICE_ID) : null) ||
    (items.length === 1 ? items[0] : null)
  );
}

function sumPositiveProrationLines(invoiceLike) {
  const lines = invoiceLike?.lines?.data || [];

  let subtotal = 0;
  let tax = 0;

  for (const l of lines) {
    const amount = typeof l?.amount === 'number' ? l.amount : 0;
    const isProration = l?.proration === true;

    if (!isProration || amount <= 0) continue;

    subtotal += amount;

    const taxAmounts = Array.isArray(l?.tax_amounts) ? l.tax_amounts : [];
    for (const t of taxAmounts) {
      const ta = typeof t?.amount === 'number' ? t.amount : 0;
      if (ta > 0) tax += ta;
    }
  }

  return { subtotalCents: subtotal, taxCents: tax, totalCents: subtotal + tax };
}

function pickInvoiceTotals(invoiceLike) {
  const subtotal = typeof invoiceLike?.subtotal === 'number' ? invoiceLike.subtotal : 0;
  const total = typeof invoiceLike?.total === 'number' ? invoiceLike.total : 0;

  let tax = 0;
  const tta = Array.isArray(invoiceLike?.total_tax_amounts) ? invoiceLike.total_tax_amounts : [];
  for (const t of tta) {
    const ta = typeof t?.amount === 'number' ? t.amount : 0;
    if (ta > 0) tax += ta;
  }

  const safeTotal = total > 0 ? total : (subtotal + tax);

  return {
    subtotalCents: subtotal,
    taxCents: tax,
    totalCents: safeTotal,
  };
}

function buildQuery(params) {
  const parts = [];
  const push = (k, v) => {
    if (v === undefined || v === null) return;
    parts.push(`${encodeURIComponent(k)}=${encodeURIComponent(String(v))}`);
  };

  for (const [k, v] of Object.entries(params || {})) {
    if (Array.isArray(v)) {
      if (k === 'expand') {
        for (const item of v) push('expand[]', item);
      } else if (k === 'subscription_items') {
        v.forEach((it, idx) => {
          for (const [ik, iv] of Object.entries(it || {})) {
            push(`subscription_items[${idx}][${ik}]`, iv);
          }
        });
      } else {
        v.forEach((item) => push(`${k}[]`, item));
      }
    } else {
      push(k, v);
    }
  }

  return parts.length ? `?${parts.join('&')}` : '';
}

async function retrieveUpcomingViaRaw(stripe, params) {
  const qs = buildQuery(params);
  const res = await stripe.rawRequest('get', `/v1/invoices/upcoming${qs}`, null);
  return res?.data || null;
}

exports.stripe_previewSeatChange = onCall(
    { region: 'europe-west1', secrets: ['STRIPE_SECRET_KEY'] },
    async (request) => {
      try {
        assertAuth(request);
        const uid = request.auth.uid;

        const { companyId, newTotalSeats } = request.data || {};
        if (!companyId) throw new HttpsError('invalid-argument', 'companyId requerido');
        if (!Number.isInteger(newTotalSeats) || newTotalSeats < 1) {
          throw new HttpsError('invalid-argument', 'newTotalSeats inválido');
        }

        await assertCompanyAccount(uid, companyId);

        const PRICE_ID = String(process.env.PRICE_ID || '').trim();
        if (!PRICE_ID) throw new HttpsError('failed-precondition', 'PRICE_ID no configurado');

        const snap = await db.collection('companies').doc(companyId).get();
        if (!snap.exists) throw new HttpsError('not-found', 'Empresa no encontrada');

        const company = snap.data() || {};
        const customerId = String(company.stripeCustomerId || '').trim();
        const subscriptionId = String(company.stripeSubscriptionId || '').trim();
        if (!customerId) throw new HttpsError('failed-precondition', 'Empresa sin stripeCustomerId');

        const stripe = getStripe();

        // Total seats en tu UI. En Stripe qty = paid seats (1 gratis fuera)
        const newPaidSeats = Math.max(newTotalSeats - 1, 0);

        // Caso: llevarlo a 1 total (0 de pago). Hoy no pagas nada por seats.
        if (newPaidSeats === 0) {
          return {
            ok: true,
            currency: 'eur',
            noPaymentNow: true,
            nowSubtotalCents: 0,
            nowTaxCents: 0,
            nowTotalCents: 0,
            nextSubtotalCents: 0,
            nextTaxCents: 0,
            nextTotalCents: 0,
            currentTotalSeats: null,
            newTotalSeats,
            mode: 'free_or_downgrade_to_free',
          };
        }

        // Si no hay suscripción aún, no puedes “prorratear” contra un ciclo existente.
        // Si quieres TAX real aquí, hay que hacer un preview diferente (p.ej. Tax Calculation / Checkout).
        if (!subscriptionId) {
          return {
            ok: true,
            currency: 'eur',
            noPaymentNow: false,
            nowSubtotalCents: 0,
            nowTaxCents: 0,
            nowTotalCents: 0,
            nextSubtotalCents: 0,
            nextTaxCents: 0,
            nextTotalCents: 0,
            currentTotalSeats: 1,
            newTotalSeats,
            mode: 'no_subscription_yet',
          };
        }

        // Sub actual
        const sub = await stripe.subscriptions.retrieve(subscriptionId, {
          expand: ['items.data.price'],
        });

        const currency = sub?.currency || 'eur';

        const seatItem = getSeatItemFromSub({ sub, PRICE_ID });
        if (!seatItem?.id) {
          throw new HttpsError(
              'failed-precondition',
              'No se encontró el item de seats (PRICE_ID no coincide)',
          );
        }

        const currentPaidSeats = typeof seatItem.quantity === 'number' ? seatItem.quantity : 0;
        const currentTotalSeats = currentPaidSeats + 1;
        const deltaPaid = newPaidSeats - currentPaidSeats;

        // PREVIEW PRÓXIMO CICLO (SIEMPRE que haya suscripción):
        // ✅ NO mandes subscription_proration_date (si no hay prorrateo, Stripe peta)
        const previewNext = await retrieveUpcomingViaRaw(stripe, {
          customer: customerId,
          subscription: subscriptionId,
          subscription_items: [{ id: seatItem.id, quantity: newPaidSeats }],
          expand: ['lines'],
        });
        const next = pickInvoiceTotals(previewNext);

        // Downgrade o sin cambios => hoy 0
        if (deltaPaid <= 0) {
          return {
            ok: true,
            currency: previewNext?.currency || currency,
            noPaymentNow: true,
            nowSubtotalCents: 0,
            nowTaxCents: 0,
            nowTotalCents: 0,
            nextSubtotalCents: next.subtotalCents,
            nextTaxCents: next.taxCents,
            nextTotalCents: next.totalCents,
            currentTotalSeats,
            newTotalSeats,
            mode: deltaPaid === 0 ? 'unchanged' : 'downgrade',
          };
        }

        // ── UPGRADE: PREVIEW “PAGARÁS HOY” (prorrateo) ──
        const now = Math.floor(Date.now() / 1000);

        const previewNow = await retrieveUpcomingViaRaw(stripe, {
          customer: customerId,
          subscription: subscriptionId,
          subscription_proration_date: now,
          subscription_proration_behavior: 'create_prorations',
          subscription_items: [{ id: seatItem.id, quantity: newPaidSeats }],
          expand: ['lines'],
        });

        const nowParts = sumPositiveProrationLines(previewNow);

        return {
          ok: true,
          currency: previewNow?.currency || currency,

          // “Lo que pagarás YA” = SOLO prorrateo positivo (con IVA de esas líneas)
          noPaymentNow: nowParts.totalCents <= 0,
          nowSubtotalCents: nowParts.subtotalCents,
          nowTaxCents: nowParts.taxCents,
          nowTotalCents: nowParts.totalCents,

          // “Lo que pagarás el próximo ciclo” = total de la próxima factura ya con la qty nueva
          nextSubtotalCents: next.subtotalCents,
          nextTaxCents: next.taxCents,
          nextTotalCents: next.totalCents,

          currentTotalSeats,
          newTotalSeats,
          mode: 'upgrade',
        };
      } catch (err) {
        logger.error('[stripe_previewSeatChange]', { msg: err?.message, stack: err?.stack });
        if (err instanceof HttpsError) throw err;
        throw new HttpsError('internal', err?.message || 'Error interno');
      }
    },
);
