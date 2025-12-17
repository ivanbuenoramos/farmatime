const { onCall, HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');

const { db } = require('../config/firebase');
const { assertAuth, assertCompanyAccount } = require('../helpers/assertions');
const { getStripe } = require('../config/stripe');

exports.stripe_createCustomer = onCall(
    { region: 'europe-west1', secrets: ['STRIPE_SECRET_KEY'] },
    async (request) => {
      try {
        assertAuth(request);

        const uid = request.auth.uid;
        const { companyId } = request.data || {};

        if (!companyId) throw new HttpsError('invalid-argument', 'companyId requerido');
        await assertCompanyAccount(uid, companyId);

        const ref = db.collection('companies').doc(companyId);
        const snap = await ref.get();
        if (!snap.exists) throw new HttpsError('not-found', 'Empresa no encontrada');

        const company = snap.data() || {};
        const existing = String(company.stripeCustomerId || '').trim();
        if (existing) return { ok: true, customerId: existing };

        const stripe = getStripe();

        const customer = await stripe.customers.create({
          metadata: { companyId },
        });

        await ref.update({
          stripeCustomerId: customer.id,
          stripeSubscriptionId: null,
          contractedSeats: company.contractedSeats ?? 1, // mínimo 1
          updatedAt: new Date(),
        });

        return { ok: true, customerId: customer.id };
      } catch (err) {
        logger.error('[stripe_createCustomer]', { msg: err?.message, stack: err?.stack });
        if (err instanceof HttpsError) throw err;
        throw new HttpsError('internal', err?.message || 'Error interno');
      }
    },
);
