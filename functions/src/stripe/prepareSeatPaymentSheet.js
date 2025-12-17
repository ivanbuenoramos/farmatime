// src/stripe/prepareSeatPaymentSheet.js
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');

const { db, admin } = require('../config/firebase');
const { assertAuth, assertCompanyAccount } = require('../helpers/assertions');
const { getStripe } = require('../config/stripe');

async function getSeatItem(sub, PRICE_ID) {
  const items = sub?.items?.data || [];
  return (
    (PRICE_ID ? items.find((i) => i?.price?.id === PRICE_ID) : null) ||
    (items.length === 1 ? items[0] : null)
  );
}

async function ensureClientSecret(stripe, invoiceId) {
  if (!invoiceId) return null;

  let invoice = await stripe.invoices.retrieve(invoiceId, {
    expand: ['payment_intent'],
  });

  if (invoice.status === 'draft') {
    invoice = await stripe.invoices.finalizeInvoice(invoiceId, {
      expand: ['payment_intent'],
    });
  }

  const pi = invoice.payment_intent;
  return typeof pi === 'string' ? null : pi?.client_secret ?? null;
}

exports.stripe_prepareSeatPaymentSheet = onCall(
    { region: 'europe-west1', secrets: ['STRIPE_SECRET_KEY'] },
    async (request) => {
      try {
        assertAuth(request);

        const { companyId, newTotalSeats } = request.data || {};
        if (!companyId || !Number.isInteger(newTotalSeats) || newTotalSeats < 1) {
          throw new HttpsError('invalid-argument', 'Datos inválidos');
        }

        await assertCompanyAccount(request.auth.uid, companyId);

        const PRICE_ID = String(process.env.PRICE_ID || '').trim();
        if (!PRICE_ID) {
          throw new HttpsError('failed-precondition', 'PRICE_ID no configurado');
        }

        const ref = db.collection('companies').doc(companyId);
        const snap = await ref.get();
        if (!snap.exists) throw new HttpsError('not-found', 'Empresa no encontrada');

        const company = snap.data() || {};
        const customerId = String(company.stripeCustomerId || '').trim();
        let subscriptionId = String(company.stripeSubscriptionId || '').trim();

        if (!customerId) {
          throw new HttpsError('failed-precondition', 'Empresa sin stripeCustomerId');
        }

        const stripe = getStripe();

        // 🔒 Regla: 1 asiento gratis
        const newPaidSeats = Math.max(newTotalSeats - 1, 0);

        // Si solo queda el gratis → no hay pago
        if (newPaidSeats === 0) {
          if (subscriptionId) {
            const sub = await stripe.subscriptions.retrieve(subscriptionId, {
              expand: ['items.data.price'],
            });
            const seatItem = await getSeatItem(sub, PRICE_ID);
            if (seatItem?.id) {
              await stripe.subscriptions.update(subscriptionId, {
                proration_behavior: 'none',
                items: [{ id: seatItem.id, quantity: 0 }],
              });
            }
          }
          return { ok: true, noPayment: true };
        }

        // Ephemeral Key (una vez)
        const eph = await stripe.ephemeralKeys.create(
            { customer: customerId },
            { apiVersion: '2024-06-20' },
        );

        // ─────────────────────────────────────────
        // CASO A: EXISTE SUSCRIPCIÓN
        // ─────────────────────────────────────────
        if (subscriptionId) {
          const sub = await stripe.subscriptions.retrieve(subscriptionId, {
            expand: ['latest_invoice.payment_intent', 'items.data.price'],
          });

          // ❌ Si está muerta → se cancela y se recrea
          if (sub.status === 'incomplete_expired') {
            await stripe.subscriptions.cancel(subscriptionId);

            await ref.set(
                {
                  stripeSubscriptionId: null,
                  billingStatus: 'none',
                  contractedSeats: 1,
                  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                },
                { merge: true },
            );

            subscriptionId = '';
          }

          // 🔁 Si está incomplete → REINTENTO
          if (sub.status === 'incomplete') {
            const seatItem = await getSeatItem(sub, PRICE_ID);
            const currentPaidSeats = seatItem?.quantity ?? 0;

            let updatedSub = sub;

            if (seatItem?.id && currentPaidSeats !== newPaidSeats) {
              updatedSub = await stripe.subscriptions.update(subscriptionId, {
                proration_behavior: 'none',
                payment_behavior: 'default_incomplete',
                items: [{ id: seatItem.id, quantity: newPaidSeats }],
                expand: ['latest_invoice.payment_intent'],
              });
            }

            const invoiceId =
              typeof updatedSub.latest_invoice === 'string' ?
                updatedSub.latest_invoice :
                updatedSub.latest_invoice?.id;

            const clientSecret = await ensureClientSecret(stripe, invoiceId);
            if (!clientSecret) {
              throw new HttpsError('failed-precondition', 'No se pudo recuperar el pago pendiente');
            }

            return {
              ok: true,
              noPayment: false,
              customerId,
              ephemeralKey: eph.secret,
              paymentIntentClientSecret: clientSecret,
            };
          }
        }

        // ─────────────────────────────────────────
        // CASO B: NO HAY SUSCRIPCIÓN (o se limpió)
        // ─────────────────────────────────────────
        if (!subscriptionId) {
          const sub = await stripe.subscriptions.create({
            customer: customerId,
            items: [{ price: PRICE_ID, quantity: newPaidSeats }],
            collection_method: 'charge_automatically',
            payment_behavior: 'default_incomplete',
            expand: ['latest_invoice.payment_intent'],
            metadata: { companyId },
          });

          const invoiceId =
            typeof sub.latest_invoice === 'string' ?
              sub.latest_invoice :
              sub.latest_invoice?.id;

          const clientSecret = await ensureClientSecret(stripe, invoiceId);
          if (!clientSecret) {
            throw new HttpsError('internal', 'No se pudo crear PaymentIntent');
          }

          await ref.set(
              {
                stripeSubscriptionId: sub.id,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
              { merge: true },
          );

          return {
            ok: true,
            noPayment: false,
            customerId,
            ephemeralKey: eph.secret,
            paymentIntentClientSecret: clientSecret,
          };
        }

        // ─────────────────────────────────────────
        // CASO C: UPGRADE NORMAL
        // ─────────────────────────────────────────
        const currentSub = await stripe.subscriptions.retrieve(subscriptionId, {
          expand: ['items.data.price'],
        });

        const seatItem = await getSeatItem(currentSub, PRICE_ID);
        if (!seatItem?.id) {
          throw new HttpsError('failed-precondition', 'Item de seats no encontrado');
        }

        const currentPaidSeats = seatItem.quantity ?? 0;

        if (newPaidSeats <= currentPaidSeats) {
          return { ok: true, noPayment: true };
        }

        const updated = await stripe.subscriptions.update(subscriptionId, {
          proration_behavior: 'create_prorations',
          payment_behavior: 'default_incomplete',
          items: [{ id: seatItem.id, quantity: newPaidSeats }],
          expand: ['latest_invoice.payment_intent'],
        });

        const invoiceId =
          typeof updated.latest_invoice === 'string' ?
            updated.latest_invoice :
            updated.latest_invoice?.id;

        const clientSecret = await ensureClientSecret(stripe, invoiceId);
        if (!clientSecret) {
          return { ok: true, noPayment: true };
        }

        return {
          ok: true,
          noPayment: false,
          customerId,
          ephemeralKey: eph.secret,
          paymentIntentClientSecret: clientSecret,
        };
      } catch (err) {
        logger.error('[stripe_prepareSeatPaymentSheet]', {
          msg: err?.message,
          stack: err?.stack,
        });
        if (err instanceof HttpsError) throw err;
        throw new HttpsError('internal', err?.message || 'Error interno');
      }
    },
);
