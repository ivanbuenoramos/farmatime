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

function getPaidSeatsFromSub(sub) {
  const q = sub?.items?.data?.[0]?.quantity;
  return typeof q === 'number' ? q : 0;
}

async function retrieveSubMinimal(stripe, subId) {
  return stripe.subscriptions.retrieve(subId, { expand: ['items.data'] });
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

    switch (event.type) {
      /* ───────────────────── INVOICE UPCOMING (aplicar downgrade antes de facturar) ───────────────────── */
      case 'invoice.upcoming': {
        const inv = event.data.object;

        const stripeCustomerId = getCustomerId(inv.customer);
        const companyId = await getCompanyIdFromCustomer(stripeCustomerId);
        if (!companyId) break;

        const companySnap = await db.collection('companies').doc(companyId).get();
        const company = companySnap.data() || {};

        const scheduledPaidSeats = typeof company.scheduledPaidSeats === 'number' ? company.scheduledPaidSeats : null;
        const scheduledForPeriodEnd = company.scheduledForPeriodEnd instanceof admin.firestore.Timestamp ?
          company.scheduledForPeriodEnd.toMillis() :
          null;

        // Solo si hay programación
        if (scheduledPaidSeats == null || scheduledForPeriodEnd == null) break;

        // Stripe invoice period_end viene en unix seconds
        const invoicePeriodEndMs = (inv.period_end || 0) * 1000;

        // Aplicamos el cambio justo para ese cierre de periodo (tolerancia 1h)
        if (Math.abs(invoicePeriodEndMs - scheduledForPeriodEnd) > 60 * 60 * 1000) break;

        const subId = typeof inv.subscription === 'string' ? inv.subscription : inv.subscription?.id;
        if (!subId) break;

        const stripe = getStripe();
        const sub = await stripe.subscriptions.retrieve(subId, { expand: ['items.data'] });
        const item = sub?.items?.data?.[0];
        if (!item?.id) break;

        await stripe.subscriptions.update(subId, {
          proration_behavior: 'none',
          items: [{ id: item.id, quantity: scheduledPaidSeats }],
        });

        // Limpiamos programación (ya aplicada)
        await updateCompanyMirror(companyId, {
          scheduledSeats: null,
          scheduledPaidSeats: null,
          scheduledForPeriodEnd: null,
        });

        logger.info('[invoice.upcoming] applied scheduledPaidSeats', { companyId, subId, scheduledPaidSeats });
        break;
      }

      /* ───────────────────── SUBSCRIPTION CREATED ───────────────────── */
      case 'customer.subscription.created': {
        const sub = event.data.object;

        const stripeCustomerId = getCustomerId(sub.customer);
        const companyId =
          sub.metadata?.companyId || (await getCompanyIdFromCustomer(stripeCustomerId));

        if (!companyId) break;

        await updateCompanyMirror(companyId, {
          stripeCustomerId,
          stripeSubscriptionId: sub.id,
          billingStatus: sub.status,
          currentPeriodEnd: sub.current_period_end,
        });

        await updateEmployeesForBillingState(companyId);
        break;
      }

      /* ───────────────────── SUBSCRIPTION UPDATED ───────────────────── */
      case 'customer.subscription.updated': {
        const sub = event.data.object;

        const stripeCustomerId = getCustomerId(sub.customer);
        const companyId =
          sub.metadata?.companyId || (await getCompanyIdFromCustomer(stripeCustomerId));

        if (!companyId) break;

        await updateCompanyMirror(companyId, {
          stripeCustomerId,
          stripeSubscriptionId: sub.id,
          billingStatus: sub.status,
          currentPeriodEnd: sub.current_period_end,
        });

        await updateEmployeesForBillingState(companyId);
        break;
      }

      /* ───────────────────── INVOICE PAID ───────────────────── */
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

        const companySnap = await db.collection('companies').doc(companyId).get();
        const company = companySnap.data() || {};

        const pendingSeats =
          typeof company.pendingSeats === 'number' && company.pendingSeats >= 1 ?
            company.pendingSeats :
            null;

        const subId =
          typeof inv.subscription === 'string' ? inv.subscription : inv.subscription?.id;

        if (subId) {
          const s = await retrieveSubMinimal(stripe, subId);

          const paidSeats = getPaidSeatsFromSub(s);
          const totalSeatsFromStripe = paidSeats + 1;

          // ✅ Si había upgrade pendiente, aplicamos lo pedido.
          // Si no, sincronizamos desde Stripe (incluye downgrades ya aplicados en invoice.upcoming)
          const finalSeats = pendingSeats ?? totalSeatsFromStripe;

          await updateCompanyMirror(companyId, {
            stripeCustomerId,
            stripeSubscriptionId: s.id,
            billingStatus: s.status,
            currentPeriodEnd: s.current_period_end,
            contractedSeats: finalSeats,
            pendingSeats: null,
          });

          await updateEmployeesForBillingState(companyId);
        } else {
          // Invoice sin subscription: limpiamos pending
          await updateCompanyMirror(companyId, {
            stripeCustomerId,
            billingStatus: 'active',
            contractedSeats: pendingSeats ?? (company.contractedSeats ?? 1),
            pendingSeats: null,
          });
          await updateEmployeesForBillingState(companyId);
        }

        break;
      }

      /* ───────────────────── INVOICE PAYMENT FAILED ───────────────────── */
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

        await updateCompanyMirror(companyId, { billingStatus: 'past_due' });
        await updateEmployeesForBillingState(companyId);
        break;
      }

      /* ───────────────────── SUBSCRIPTION DELETED ───────────────────── */
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
          pendingSeats: null,
          scheduledSeats: null,
          scheduledPaidSeats: null,
          scheduledForPeriodEnd: null,
          currentPeriodEnd: null,
        });

        await updateEmployeesForBillingState(companyId);
        break;
      }

      default:
        logger.info(`Evento no manejado: ${event.type}`);
    }
  } catch (e) {
    logger.error('❌ Error manejando webhook', { msg: e.message, stack: e.stack });
    return res.status(500).send('Internal error');
  }

  return res.json({ received: true });
});
