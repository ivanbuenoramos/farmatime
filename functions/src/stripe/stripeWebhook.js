// Webhook de Stripe (Firebase Functions v2 + CommonJS)

const { onRequest } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');

const { db, admin } = require('../config/firebase');
const { getStripe } = require('../config/stripe');
const {
  updateCompanyMirror,
  getCompanyIdFromCustomer,
} = require('../helpers/companyMirror');
const {
  updateEmployeesForBillingState,
} = require('../helpers/billingEmployees');

const WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET;

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

  logger.info('➡️ Stripe webhook recibido', {
    type: event.type,
    id: event.id,
  });

  try {
    switch (event.type) {
      /* ───────────────────── SUBSCRIPTION CREATED ───────────────────── */
      case 'customer.subscription.created': {
        const sub = event.data.object;
        const stripeCustomerId =
          typeof sub.customer === 'string' ? sub.customer : sub.customer.id;

        const companyId =
          sub.metadata?.companyId ||
          (await getCompanyIdFromCustomer(stripeCustomerId));

        // quantity de la primera línea de la suscripción
        const qty =
          sub.items &&
          sub.items.data &&
          sub.items.data[0] &&
          typeof sub.items.data[0].quantity === 'number' ?
            sub.items.data[0].quantity :
            null;

        logger.info('[subscription.created]', {
          companyId,
          stripeCustomerId,
          status: sub.status,
          quantity: qty,
        });

        if (!companyId) {
          logger.error(
              '[subscription.created] companyId vacío. No actualizo Firestore.',
          );
          break;
        }

        await updateCompanyMirror(companyId, {
          billingStatus: sub.status,
          currentPeriodEnd: sub.current_period_end,
          contractedSeats: typeof qty === 'number' ? qty : undefined,
        });

        // Arranca la sub → modo según status (normalmente active)
        let mode = 'active';
        if (sub.status === 'canceled') {
          mode = 'canceled_nonpayment';
        } else if (sub.status !== 'active') {
          mode = 'payment_failed';
        }

        await updateEmployeesForBillingState(companyId, { mode });

        break;
      }

      /* ───────────────────── SUBSCRIPTION UPDATED ───────────────────── */
      case 'customer.subscription.updated': {
        const sub = event.data.object;
        const stripeCustomerId =
          typeof sub.customer === 'string' ? sub.customer : sub.customer.id;

        const companyId =
          sub.metadata?.companyId ||
          (await getCompanyIdFromCustomer(stripeCustomerId));

        const reason = sub.cancellation_details?.reason || null;

        const qty =
          sub.items &&
          sub.items.data &&
          sub.items.data[0] &&
          typeof sub.items.data[0].quantity === 'number' ?
            sub.items.data[0].quantity :
            null;

        logger.info('[subscription.updated]', {
          companyId,
          stripeCustomerId,
          status: sub.status,
          reason,
          quantity: qty,
        });

        if (!companyId) {
          logger.error(
              '[subscription.updated] companyId vacío. No actualizo Firestore.',
          );
          break;
        }

        await updateCompanyMirror(companyId, {
          billingStatus: sub.status,
          currentPeriodEnd: sub.current_period_end,
          // 👈 IMPORTANTE: actualizamos también las plazas
          contractedSeats: typeof qty === 'number' ? qty : undefined,
        });

        // Decidimos el modo para los empleados
        let mode;
        if (sub.status === 'active') {
          mode = 'active';
        } else if (sub.status === 'canceled') {
          // Si viene cancelada y la razón es fallo de pago
          if (reason === 'failed_invoice') {
            mode = 'canceled_nonpayment';
          } else {
            // Otras cancelaciones (por ahora, mismo tratamiento)
            mode = 'canceled_nonpayment';
          }
        } else {
          // past_due, unpaid, etc.
          mode = 'payment_failed';
        }

        await updateEmployeesForBillingState(companyId, { mode });
        break;
      }

      /* ───────────────────── INVOICE PAID ───────────────────── */
      case 'invoice.paid': {
        const inv = event.data.object;
        const stripeCustomerId =
          typeof inv.customer === 'string' ? inv.customer : inv.customer.id;

        const companyId = await getCompanyIdFromCustomer(stripeCustomerId);

        logger.info('[invoice.paid]', {
          companyId,
          stripeCustomerId,
          amount_paid: inv.amount_paid,
        });

        if (!companyId) {
          logger.error('[invoice.paid] companyId vacío. No actualizo Firestore.');
          break;
        }

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
                    date: admin.firestore.Timestamp.fromMillis(
                        (inv.created || 0) * 1000,
                    ),
                    pdfUrl: inv.invoice_pdf || null,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                  },
                  { merge: true },
              );
        }

        const stripe = getStripe();
        const subId =
          typeof inv.subscription === 'string' ?
            inv.subscription :
            inv.subscription?.id;

        if (subId) {
          const s = await stripe.subscriptions.retrieve(subId, {
            expand: ['items.data'],
          });
          const newQty =
            s?.items?.data?.[0] &&
            typeof s.items.data[0].quantity === 'number' ?
              s.items.data[0].quantity :
              null;

          logger.info('[invoice.paid] sync subscription', {
            companyId,
            subId,
            status: s.status,
            quantity: newQty,
          });

          await updateCompanyMirror(companyId, {
            contractedSeats: typeof newQty === 'number' ? newQty : undefined,
            billingStatus: s.status,
            currentPeriodEnd: s.current_period_end,
          });

          // Después de un pago correcto, recalculamos empleados
          const mode = s.status === 'active' ? 'active' : 'payment_failed';
          await updateEmployeesForBillingState(companyId, { mode });
        }
        break;
      }

      /* ───────────────────── INVOICE PAYMENT FAILED ───────────────────── */
      case 'invoice.payment_failed': {
        const inv = event.data.object;
        const stripeCustomerId =
          typeof inv.customer === 'string' ? inv.customer : inv.customer.id;

        const companyId = await getCompanyIdFromCustomer(stripeCustomerId);

        logger.info('[invoice.payment_failed]', {
          companyId,
          stripeCustomerId,
          amount_due: inv.amount_due,
        });

        if (!companyId) {
          logger.error(
              '[invoice.payment_failed] companyId vacío. No actualizo Firestore.',
          );
          break;
        }

        await updateCompanyMirror(companyId, { billingStatus: 'past_due' });

        await updateEmployeesForBillingState(companyId, {
          mode: 'payment_failed',
        });

        break;
      }

      /* ───────────────────── SUBSCRIPTION DELETED ───────────────────── */
      case 'customer.subscription.deleted': {
        const sub = event.data.object;
        const stripeCustomerId =
          typeof sub.customer === 'string' ? sub.customer : sub.customer.id;

        const companyId =
          sub.metadata?.companyId ||
          (await getCompanyIdFromCustomer(stripeCustomerId));

        logger.info('[subscription.deleted]', {
          companyId,
          stripeCustomerId,
          status: sub.status,
          reason: sub.cancellation_details?.reason || null,
        });

        if (!companyId) break;

        await updateCompanyMirror(companyId, {
          billingStatus: 'canceled',
          currentPeriodEnd: sub.current_period_end,
        });

        // Cancelada → todos (menos el histórico que decidas) a disabled
        await updateEmployeesForBillingState(companyId, {
          mode: 'canceled_nonpayment',
        });

        break;
      }

      default:
        logger.info(`Evento no manejado: ${event.type}`);
    }
  } catch (e) {
    logger.error('❌ Error manejando webhook', {
      msg: e.message,
      stack: e.stack,
    });
    return res.status(500).send('Internal error');
  }

  return res.json({ received: true });
});
