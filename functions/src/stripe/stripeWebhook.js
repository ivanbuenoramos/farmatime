// src/stripe/stripeWebhook.js
const { onRequest } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');

const { db, admin } = require('../config/firebase');
const { getStripe } = require('../config/stripe');
const { updateCompanyMirror, getCompanyIdFromCustomer } = require('../helpers/companyMirror');
const { updateEmployeesForBillingState } = require('../helpers/billingEmployees');

const WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET;

function getCustomerId(obj) {
  if (!obj) return '';
  return typeof obj === 'string' ? obj : (obj.id || '');
}

// ✅ Stripe quantity = PAID seats (total-1)
function getPaidSeatsFromSub(sub, PRICE_ID) {
  const items = sub?.items?.data || [];
  const seatItem =
    (PRICE_ID ? items.find((i) => i?.price?.id === PRICE_ID) : null) ||
    (items.length === 1 ? items[0] : null);

  const q = seatItem?.quantity;
  return typeof q === 'number' && q >= 0 ? q : 0;
}

async function retrieveSubExpanded(stripe, subId) {
  return stripe.subscriptions.retrieve(subId, { expand: ['items.data.price'] });
}

exports.stripe_webhook = onRequest(async (req, res) => {
  const sig = req.headers['stripe-signature'];

  if (!WEBHOOK_SECRET) {
    logger.error('⚠️ Falta STRIPE_WEBHOOK_SECRET en secretos');
    return res.status(500).send('Webhook secret no configurado');
  }

  let event;
  try {
    const stripe = getStripe();
    event = stripe.webhooks.constructEvent(req.rawBody, sig, WEBHOOK_SECRET);
  } catch (err) {
    logger.error('❌ Verificación de firma fallida', { msg: err.message });
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  logger.info('➡️ Stripe webhook recibido', { type: event.type, id: event.id });

  try {
    const stripe = getStripe();
    const PRICE_ID = String(process.env.PRICE_ID || '').trim();

    switch (event.type) {
      case 'customer.subscription.created': {
        const sub = event.data.object;

        const stripeCustomerId = getCustomerId(sub.customer);
        const companyId =
          sub.metadata?.companyId || (await getCompanyIdFromCustomer(stripeCustomerId));

        if (!companyId) break;

        const fullSub = await retrieveSubExpanded(stripe, sub.id);
        const paidSeats = getPaidSeatsFromSub(fullSub, PRICE_ID);
        const contractedSeats = paidSeats + 1;

        await updateCompanyMirror(companyId, {
          stripeCustomerId,
          stripeSubscriptionId: fullSub.id,
          billingStatus: fullSub.status,
          currentPeriodEnd: fullSub.current_period_end,
          contractedSeats, // ✅ SIEMPRE
        });

        await updateEmployeesForBillingState(companyId);
        break;
      }

      case 'customer.subscription.updated': {
        const sub = event.data.object;

        const stripeCustomerId = getCustomerId(sub.customer);
        const companyId =
          sub.metadata?.companyId || (await getCompanyIdFromCustomer(stripeCustomerId));

        if (!companyId) break;

        const fullSub = await retrieveSubExpanded(stripe, sub.id);
        const paidSeats = getPaidSeatsFromSub(fullSub, PRICE_ID);
        const contractedSeats = paidSeats + 1;

        await updateCompanyMirror(companyId, {
          stripeCustomerId,
          stripeSubscriptionId: fullSub.id,
          billingStatus: fullSub.status,
          currentPeriodEnd: fullSub.current_period_end,
          contractedSeats, // ✅ SIEMPRE
        });

        await updateEmployeesForBillingState(companyId);
        break;
      }

      case 'invoice.paid': {
        const inv = event.data.object;

        const stripeCustomerId = getCustomerId(inv.customer);
        const companyId = await getCompanyIdFromCustomer(stripeCustomerId);

        logger.info('[invoice.paid]', {
          companyId,
          stripeCustomerId,
          amount_paid: inv.amount_paid,
          invoiceId: inv.id,
        });

        if (!companyId) break;

        // Guardar invoice (solo si importe > 0)
        if ((inv.amount_paid ?? 0) > 0) {
          await db
              .collection('companies')
              .doc(companyId)
              .collection('invoices')
              .doc(inv.id)
              .set(
                  {
                    number: inv.number || inv.id,
                    amountCents: inv.amount_paid || 0,
                    date: admin.firestore.Timestamp.fromMillis((inv.created || 0) * 1000),
                    pdfUrl: inv.invoice_pdf || null,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                  },
                  { merge: true },
              );
        }

        // Si hay subscription en el invoice, sincroniza desde Stripe (FUENTE DE VERDAD)
        const subId =
          typeof inv.subscription === 'string' ? inv.subscription : inv.subscription?.id;

        if (subId) {
          const fullSub = await retrieveSubExpanded(stripe, subId);
          const paidSeats = getPaidSeatsFromSub(fullSub, PRICE_ID);
          const contractedSeats = paidSeats + 1;

          await updateCompanyMirror(companyId, {
            stripeCustomerId,
            stripeSubscriptionId: fullSub.id,
            billingStatus: fullSub.status,
            currentPeriodEnd: fullSub.current_period_end,
            contractedSeats,
          });

          await updateEmployeesForBillingState(companyId);
        } else {
          // Invoice sin subscription (raro aquí). Al menos marca active
          await updateCompanyMirror(companyId, {
            stripeCustomerId,
            billingStatus: 'active',
          });
          await updateEmployeesForBillingState(companyId);
        }

        break;
      }

      case 'invoice.payment_failed': {
        const inv = event.data.object;

        const stripeCustomerId = getCustomerId(inv.customer);
        const companyId = await getCompanyIdFromCustomer(stripeCustomerId);

        logger.info('[invoice.payment_failed]', {
          companyId,
          stripeCustomerId,
          amount_due: inv.amount_due,
          invoiceId: inv.id,
        });

        if (!companyId) break;

        // Aquí puedes implementar tu gracia de 30 días si quieres:
        // - o guardas graceUntil = now + 30d
        // - o graceUntil = currentPeriodEnd + 30d (si tienes sub)
        await updateCompanyMirror(companyId, { billingStatus: 'past_due' });
        await updateEmployeesForBillingState(companyId);
        break;
      }

      case 'customer.subscription.deleted': {
        const sub = event.data.object;

        const stripeCustomerId = getCustomerId(sub.customer);
        const companyId =
          sub.metadata?.companyId || (await getCompanyIdFromCustomer(stripeCustomerId));

        logger.info('[subscription.deleted]', {
          companyId,
          stripeCustomerId,
          subId: sub.id,
          status: sub.status,
        });

        if (!companyId) break;

        await updateCompanyMirror(companyId, {
          stripeCustomerId,
          stripeSubscriptionId: null,
          billingStatus: 'none',
          contractedSeats: 1,
          currentPeriodEnd: null,
        });

        await updateEmployeesForBillingState(companyId);
        break;
      }

      default:
        break;
    }
  } catch (e) {
    logger.error('❌ Error manejando webhook', { msg: e.message, stack: e.stack });
    return res.status(500).send('Internal error');
  }

  return res.json({ received: true });
});
