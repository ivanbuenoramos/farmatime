// src/stripe/createSeatCheckoutSession.js
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');

const { db, admin } = require('../config/firebase');
const { assertAuth, assertCompanyAccount } = require('../helpers/assertions');
const { getStripe } = require('../config/stripe');

function getSeatItem(sub, PRICE_ID) {
  const items = sub?.items?.data || [];
  return (
    (PRICE_ID ? items.find((i) => i?.price?.id === PRICE_ID) : null) ||
    (items.length === 1 ? items[0] : null)
  );
}

async function retrieveSubExpanded(stripe, subId) {
  return stripe.subscriptions.retrieve(subId, { expand: ['items.data.price'] });
}

async function finalizeAndGetHostedUrl(stripe, invoiceId) {
  let inv = await stripe.invoices.retrieve(invoiceId);
  if (inv.status === 'draft') {
    inv = await stripe.invoices.finalizeInvoice(invoiceId);
  }
  return inv.hosted_invoice_url || null;
}

exports.stripe_createSeatCheckoutSession = onCall(
    {
      region: 'europe-west1',
      secrets: [
        'STRIPE_SECRET_KEY',
        // 'CHECKOUT_SUCCESS_URL',
        // 'CHECKOUT_CANCEL_URL',
      ],
    },
    async (request) => {
      try {
        assertAuth(request);

        const { companyId, newTotalSeats } = request.data || {};
        if (!companyId || !Number.isInteger(newTotalSeats) || newTotalSeats < 1) {
          throw new HttpsError('invalid-argument', 'Datos inválidos');
        }

        await assertCompanyAccount(request.auth.uid, companyId);

        const PRICE_ID = String(process.env.PRICE_ID || '').trim();
        if (!PRICE_ID) throw new HttpsError('failed-precondition', 'PRICE_ID no configurado');

        const successUrl = 'https://google.com';
        const cancelUrl = 'https://google.com';
        // const successUrl = String(process.env.CHECKOUT_SUCCESS_URL || '').trim();
        // const cancelUrl = String(process.env.CHECKOUT_CANCEL_URL || '').trim();
        if (!successUrl.startsWith('https://') && !successUrl.startsWith('http://')) {
          throw new HttpsError('failed-precondition', 'CHECKOUT_SUCCESS_URL inválida');
        }
        if (!cancelUrl.startsWith('https://') && !cancelUrl.startsWith('http://')) {
          throw new HttpsError('failed-precondition', 'CHECKOUT_CANCEL_URL inválida');
        }

        const ref = db.collection('companies').doc(companyId);
        const snap = await ref.get();
        if (!snap.exists) throw new HttpsError('not-found', 'Empresa no encontrada');

        const company = snap.data() || {};
        const customerId = String(company.stripeCustomerId || '').trim();
        const subscriptionId = String(company.stripeSubscriptionId || '').trim();

        if (!customerId) {
          throw new HttpsError('failed-precondition', 'Empresa sin stripeCustomerId');
        }

        const stripe = getStripe();

        // Regla: 1 asiento gratis
        const newPaidSeats = Math.max(newTotalSeats - 1, 0);

        // ─────────────────────────────────────────────
        // CASO 1: NO HAY SUSCRIPCIÓN → Checkout crea suscripción
        // ─────────────────────────────────────────────
        if (!subscriptionId) {
          if (newPaidSeats === 0) {
            return { ok: true, noPayment: true };
          }

          const session = await stripe.checkout.sessions.create({
            mode: 'subscription',
            customer: customerId,
            line_items: [{ price: PRICE_ID, quantity: newPaidSeats }],
            client_reference_id: companyId,
            subscription_data: {
              metadata: { companyId },
            },
            billing_address_collection: 'required',
            automatic_tax: {
              enabled: true,
            },
            customer_update: {
              address: 'auto',
            },
            success_url: successUrl,
            cancel_url: cancelUrl,
          });

          return { ok: true, noPayment: false, url: session.url };
        }

        // ─────────────────────────────────────────────
        // CASO 2: YA HAY SUSCRIPCIÓN → actualizar quantity
        // ─────────────────────────────────────────────
        const sub = await retrieveSubExpanded(stripe, subscriptionId);

        if (newPaidSeats === 0) {
          await stripe.subscriptions.cancel(subscriptionId);

          await ref.set(
              {
                stripeSubscriptionId: null,
                billingStatus: 'none',
                contractedSeats: 1,
                currentPeriodStart: null,
                currentPeriodEnd: null,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
              { merge: true },
          );

          return { ok: true, noPayment: true };
        }

        // Si está “muerta”, limpia y vuelve a CASO 1
        if (sub.status === 'incomplete_expired' || sub.status === 'canceled') {
          await ref.set(
              {
                stripeSubscriptionId: null,
                billingStatus: 'none',
                contractedSeats: 1,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
              { merge: true },
          );

          if (newPaidSeats === 0) return { ok: true, noPayment: true };

          const session = await stripe.checkout.sessions.create({
            mode: 'subscription',
            customer: customerId,
            line_items: [{ price: PRICE_ID, quantity: newPaidSeats }],
            client_reference_id: companyId,
            subscription_data: { metadata: { companyId } },
            billing_address_collection: 'required',
            automatic_tax: {
              enabled: true,
            },
            customer_update: {
              address: 'auto',
            },
            success_url: successUrl,
            cancel_url: cancelUrl,
          });

          return { ok: true, noPayment: false, url: session.url };
        }

        const seatItem = getSeatItem(sub, PRICE_ID);
        if (!seatItem?.id) {
          throw new HttpsError('failed-precondition', 'Item de seats no encontrado');
        }

        const currentPaidSeats = seatItem.quantity ?? 0;

        // No cambios
        if (newPaidSeats === currentPaidSeats) {
          return { ok: true, noPayment: true };
        }

        // ── DOWNGRADE (no cobro)
        if (newPaidSeats < currentPaidSeats) {
          await stripe.subscriptions.update(subscriptionId, {
            proration_behavior: 'none', // o 'create_prorations' si quieres crédito
            items: [{ id: seatItem.id, quantity: newPaidSeats }],
          });

          return { ok: true, noPayment: true };
        }

        if (newPaidSeats === 0) {
          await stripe.subscriptions.cancel(subscriptionId);
          return { ok: true, noPayment: true };
        }

        // ── UPGRADE (cobrar diferencia con prorrateo)
        // 1) Actualiza sub con prorrateo
        const updated = await stripe.subscriptions.update(subscriptionId, {
          proration_behavior: 'create_prorations',
          items: [{ id: seatItem.id, quantity: newPaidSeats }],
        });

        // 2) Genera invoice inmediata por los prorations
        const inv = await stripe.invoices.create({
          customer: customerId,
          subscription: updated.id,
          auto_advance: true,
          metadata: { companyId, reason: 'seat_upgrade_proration' },
        });

        // 3) Intenta cobrar automáticamente (si hay método por defecto)
        try {
          await stripe.invoices.pay(inv.id);
          return { ok: true, noPayment: true };
        } catch (e) {
          // Si requiere acción / no se puede cobrar, devolvemos URL Stripe-hosted
          const hostedUrl = await finalizeAndGetHostedUrl(stripe, inv.id);
          if (!hostedUrl) {
            throw new HttpsError('failed-precondition', 'No se pudo obtener hosted invoice URL');
          }
          return { ok: true, noPayment: false, url: hostedUrl };
        }
      } catch (err) {
        logger.error('[stripe_createSeatCheckoutSession]', {
          msg: err?.message,
          stack: err?.stack,
        });
        if (err instanceof HttpsError) throw err;
        throw new HttpsError('internal', err?.message || 'Error interno');
      }
    },
);
