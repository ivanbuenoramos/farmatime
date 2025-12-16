const { onCall, HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');

const { db } = require('../config/firebase');
const { assertAuth, assertCompanyAccount } = require('../helpers/assertions');
const { getStripe } = require('../config/stripe');

exports.stripe_updateSeatsAndPay = onCall(
    {
      region: 'europe-west1',
      secrets: ['STRIPE_SECRET_KEY'],
    },
    async (request) => {
      try {
        assertAuth(request);

        const uid = request.auth.uid;
        const { companyId, newTotalSeats } = request.data || {};

        if (!companyId || !Number.isInteger(newTotalSeats) || newTotalSeats < 1) {
          throw new HttpsError('invalid-argument', 'Datos inválidos');
        }

        await assertCompanyAccount(uid, companyId);

        const snap = await db.collection('companies').doc(companyId).get();
        if (!snap.exists) throw new HttpsError('not-found', 'Empresa no encontrada');

        const company = snap.data();
        const subscriptionId = company.stripeSubscriptionId;

        if (!subscriptionId) {
          throw new HttpsError('failed-precondition', 'Empresa sin suscripción');
        }

        const stripe = getStripe();

        const paidSeats = Math.max(newTotalSeats - 1, 0);

        // 🔥 ACTUALIZAMOS Y PEDIMOS LA FACTURA EXPANDIDA
        const updatedSub = await stripe.subscriptions.update(
            subscriptionId,
            {
              items: [
                {
                  id: company.stripeSubscriptionItemId ?? undefined,
                  quantity: paidSeats,
                },
              ],
              proration_behavior: 'create_prorations',
              expand: ['latest_invoice.payment_intent'],
            },
        );

        const invoice = updatedSub.latest_invoice;

        // ⬇️ No hay cargo (bajada de plazas o 0€)
        if (!invoice || !invoice.payment_intent) {
          return { ok: true };
        }

        return {
          ok: true,
          clientSecret: invoice.payment_intent.client_secret,
        };
      } catch (err) {
        logger.error('[stripe_updateSeatsAndPay]', {
          msg: err?.message,
          stack: err?.stack,
        });

        if (err instanceof HttpsError) throw err;
        throw new HttpsError('internal', err?.message || 'Error Stripe');
      }
    },
);
