// Webhook de Stripe (Firebase Functions v2 + CommonJS)

const { onRequest } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');

const { db, admin } = require('../config/firebase');
const { getStripe } = require('../config/stripe');
const { updateCompanyMirror, getCompanyIdFromCustomer } = require('../helpers/companyMirror');

// Secreto configurado como secret en setGlobalOptions()
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
    logger.error('❌ Verificación de firma fallida:', { msg: err.message });
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  try {
    switch (event.type) {
      case 'customer.subscription.updated': {
        const sub = event.data.object;
        const companyId =
          (sub.metadata && sub.metadata.companyId) ||
          (await getCompanyIdFromCustomer(sub.customer));

        await updateCompanyMirror(companyId, {
          billingStatus: sub.status,
          currentPeriodEnd: sub.current_period_end,
        });
        break;
      }

      case 'customer.subscription.created': {
        const sub = event.data.object;
        const companyId =
          (sub.metadata && sub.metadata.companyId) ||
          (await getCompanyIdFromCustomer(sub.customer));

        await updateCompanyMirror(companyId, {
          billingStatus: sub.status,
          currentPeriodEnd: sub.current_period_end,
        });
        break;
      }

      case 'invoice.paid': {
        const inv = event.data.object;
        const companyId = await getCompanyIdFromCustomer(inv.customer);

        // Guarda la factura si hay pago (>0)
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

        // Sincroniza plazas desde la suscripción real tras un pago OK
        const stripe = getStripe();
        const subId =
          typeof inv.subscription === 'string' ?
            inv.subscription :
            inv.subscription?.id;

        if (subId) {
          const s = await stripe.subscriptions.retrieve(subId, {
            expand: ['items.data'],
          });
          const newQty = s?.items?.data?.[0]?.quantity ?? null;

          await updateCompanyMirror(companyId, {
            contractedSeats: typeof newQty === 'number' ? newQty : undefined,
            billingStatus: s.status,
            currentPeriodEnd: s.current_period_end,
          });
        }
        break;
      }

      case 'invoice.payment_failed': {
        const inv = event.data.object;
        const companyId = await getCompanyIdFromCustomer(inv.customer);
        await updateCompanyMirror(companyId, { billingStatus: 'past_due' });
        break;
      }

      default:
        // Ignorar otros eventos
        logger.info(`Evento no manejado: ${event.type}`);
    }
  } catch (e) {
    logger.error('❌ Error manejando webhook:', { msg: e.message, stack: e.stack });
    return res.status(500).send('Internal error');
  }

  return res.json({ received: true });
});
