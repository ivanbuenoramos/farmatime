const { onCall, HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');

const { db } = require('../config/firebase');
const { assertAuth, assertCompanyAccount } = require('../helpers/assertions');
const { getStripe } = require('../config/stripe');

exports.stripe_previewSeatChange = onCall(
    {
      region: 'europe-west1',
      secrets: ['STRIPE_SECRET_KEY'],
    },
    async (request) => {
      try {
        // ─────────────────────────────────────────────────────────────
        // Auth & input
        // ─────────────────────────────────────────────────────────────
        assertAuth(request);

        const uid = request.auth.uid;
        const { companyId, newTotalSeats } = request.data || {};

        if (!companyId) {
          throw new HttpsError('invalid-argument', 'companyId requerido');
        }
        if (!Number.isInteger(newTotalSeats) || newTotalSeats < 1) {
          throw new HttpsError('invalid-argument', 'newTotalSeats inválido');
        }

        await assertCompanyAccount(uid, companyId);

        // ─────────────────────────────────────────────────────────────
        // Company & Stripe refs
        // ─────────────────────────────────────────────────────────────
        const snap = await db.collection('companies').doc(companyId).get();
        if (!snap.exists) {
          throw new HttpsError('not-found', 'Empresa no encontrada');
        }

        const company = snap.data() || {};
        const subscriptionId = String(company.stripeSubscriptionId || '').trim();
        const customerId = String(company.stripeCustomerId || '').trim();

        // 1 plaza gratis → solo se cobran las de pago
        const paidSeats = Math.max(newTotalSeats - 1, 0);

        // ─────────────────────────────────────────────────────────────
        // Caso gratis
        // ─────────────────────────────────────────────────────────────
        if (paidSeats === 0) {
          return {
            ok: true,
            mode: 'free',
            amountCents: 0,
            currency: 'eur',
          };
        }

        // ─────────────────────────────────────────────────────────────
        // Sin suscripción todavía → estimación simple
        // (no hay preview real posible)
        // ─────────────────────────────────────────────────────────────
        if (!subscriptionId || !customerId) {
          return {
            ok: true,
            mode: 'estimate',
            estimated: true,
            amountCents: paidSeats * 100, // 1€ por plaza (ejemplo)
            currency: 'eur',
          };
        }

        const stripe = getStripe();

        // ─────────────────────────────────────────────────────────────
        // Obtener item correcto de la suscripción
        // ─────────────────────────────────────────────────────────────
        const subscription = await stripe.subscriptions.retrieve(
            subscriptionId,
            { expand: ['items.data.price'] },
        );

        const items = subscription?.items?.data || [];
        if (!items.length) {
          throw new HttpsError('internal', 'La suscripción no tiene items');
        }

        const PRICE_ID = String(process.env.PRICE_ID || '').trim();
        let seatItem = null;

        // 1) Preferir PRICE_ID si está definido
        if (PRICE_ID) {
          seatItem = items.find((i) => i?.price?.id === PRICE_ID) || null;
        }

        // 2) Fallback: si solo hay un item, usarlo
        if (!seatItem && items.length === 1) {
          seatItem = items[0];
        }

        // 3) Error explícito si no se puede decidir
        if (!seatItem) {
          logger.error('[stripe_previewSeatChange] Seat item not found', {
            companyId,
            subscriptionId,
            PRICE_ID: PRICE_ID || null,
            availableItems: items.map((i) => ({
              itemId: i.id,
              priceId: i.price?.id,
              product: i.price?.product,
              interval: i.price?.recurring?.interval,
              currency: i.price?.currency,
            })),
          });

          throw new HttpsError(
              'failed-precondition',
              'No se encontró el item de seats en la suscripción. Revisa PRICE_ID o que la suscripción tenga un único item.',
          );
        }

        // ─────────────────────────────────────────────────────────────
        // PREVIEW OFICIAL (Stripe v19)
        // ─────────────────────────────────────────────────────────────
        const preview = await stripe.invoices.createPreview({
          customer: customerId,
          subscription: subscriptionId,
          subscription_items: [
            {
              id: seatItem.id,
              quantity: paidSeats,
            },
          ],
          proration_behavior: 'create_prorations',
        });

        return {
          ok: true,
          mode: 'preview',
          amountCents: preview?.total ?? 0,
          currency: preview?.currency ?? 'eur',
        };
      } catch (err) {
        logger.error('[stripe_previewSeatChange]', {
          msg: err?.message || String(err),
          stack: err?.stack || null,
        });

        if (err instanceof HttpsError) throw err;
        throw new HttpsError('internal', err?.message || 'Error interno');
      }
    },
);
