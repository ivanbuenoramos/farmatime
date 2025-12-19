// src/stripe/stripeWebhook.js
const { onRequest } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
const { db, admin } = require('../config/firebase');
const { getStripe } = require('../config/stripe');

const WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET;
const PRICE_ID = String(process.env.PRICE_ID || '').trim();

function asId(obj) {
  if (!obj) return '';
  return typeof obj === 'string' ? obj : (obj.id || '');
}

function tsFromUnixSeconds(s) {
  if (!s || typeof s !== 'number') return null;
  return admin.firestore.Timestamp.fromMillis(s * 1000);
}

// Stripe quantity = paid seats (totalSeats - 1)
function getPaidSeatsFromSubscription(sub) {
  const items = sub?.items?.data || [];
  const seatItem =
    (PRICE_ID ? items.find((i) => i?.price?.id === PRICE_ID) : null) ||
    (items.length === 1 ? items[0] : null);

  const q = seatItem?.quantity;
  return typeof q === 'number' && q >= 0 ? q : 0;
}

async function retrieveSubscriptionExpanded(stripe, subId) {
  return stripe.subscriptions.retrieve(subId, {
    expand: ['items.data.price'],
  });
}

async function findCompanyId({ companyId, customerId, subscriptionObj }) {
  // 1) metadata en subscription (lo mejor)
  const metaCompanyId = subscriptionObj?.metadata?.companyId;
  if (metaCompanyId) return String(metaCompanyId);

  // 2) companyId directo
  if (companyId) return String(companyId);

  // 3) lookup por stripeCustomerId
  if (customerId) {
    const snap = await db
        .collection('companies')
        .where('stripeCustomerId', '==', String(customerId))
        .limit(1)
        .get();
    if (!snap.empty) return snap.docs[0].id;
  }

  return '';
}

async function markEventProcessedGlobal(eventId) {
  if (!eventId) return true;

  const ref = db.collection('_stripeEvents').doc(eventId);
  const doc = await ref.get();
  if (doc.exists) return false;

  await ref.set({
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return true;
}

async function markEventProcessedForCompany(companyId, eventId) {
  if (!companyId || !eventId) return true;

  const ref = db.collection('companies').doc(companyId).collection('stripeEvents').doc(eventId);
  const doc = await ref.get();
  if (doc.exists) return false;

  await ref.set({
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return true;
}

async function updateCompany(companyId, patch) {
  if (!companyId) return;
  await db.collection('companies').doc(companyId).set(
      {
        ...patch,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
  );
}

async function syncFromSubscription({ stripe, companyId, customerId, subscriptionId }) {
  if (!subscriptionId) return;

  const fullSub = await retrieveSubscriptionExpanded(stripe, subscriptionId);

  const paidSeats = getPaidSeatsFromSubscription(fullSub);
  const contractedSeats = paidSeats + 1;

  await updateCompany(companyId, {
    stripeCustomerId: customerId || asId(fullSub.customer),
    stripeSubscriptionId: fullSub.id,
    billingStatus: fullSub.status, // active | past_due | incomplete | canceled...
    // ✅ Guardar como Timestamp (no unix number)
    currentPeriodStart: tsFromUnixSeconds(fullSub.current_period_start),
    currentPeriodEnd: tsFromUnixSeconds(fullSub.current_period_end),
    contractedSeats,
  });
}

async function saveInvoice(companyId, inv) {
  if (!companyId || !inv?.id) return;

  await db
      .collection('companies')
      .doc(companyId)
      .collection('invoices')
      .doc(inv.id)
      .set(
          {
            number: inv.number || inv.id,
            status: inv.status || null,
            currency: inv.currency || null,

            amountPaidCents: inv.amount_paid ?? 0,
            amountDueCents: inv.amount_due ?? 0,
            subtotalCents: inv.subtotal ?? 0,
            totalCents: inv.total ?? 0,

            createdAt: tsFromUnixSeconds(inv.created),
            periodStart: tsFromUnixSeconds(inv.period_start),
            periodEnd: tsFromUnixSeconds(inv.period_end),

            hostedInvoiceUrl: inv.hosted_invoice_url || null,
            pdfUrl: inv.invoice_pdf || null,

            stripeCustomerId: asId(inv.customer) || null,
            stripeSubscriptionId: asId(inv.subscription) || null,

            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
      );
}

exports.stripe_webhook = onRequest(
    { region: 'europe-west1' },
    async (req, res) => {
      if (!WEBHOOK_SECRET) {
        logger.error('Falta STRIPE_WEBHOOK_SECRET');
        return res.status(500).send('Webhook secret no configurado');
      }
      if (!PRICE_ID) {
        logger.error('Falta PRICE_ID');
        return res.status(500).send('PRICE_ID no configurado');
      }

      const sig = req.headers['stripe-signature'];
      let event;

      try {
        const stripe = getStripe();
        event = stripe.webhooks.constructEvent(req.rawBody, sig, WEBHOOK_SECRET);
      } catch (err) {
        logger.error('Verificación de firma fallida', { msg: err?.message });
        return res.status(400).send(`Webhook Error: ${err?.message}`);
      }

      const stripe = getStripe();
      logger.info('Stripe webhook recibido', { type: event.type, id: event.id });

      try {
        // Idempotencia global
        const shouldProcessGlobal = await markEventProcessedGlobal(event.id);
        if (!shouldProcessGlobal) {
          return res.json({ received: true, skipped: true });
        }

        switch (event.type) {
          // ─────────────────────────────────────────────
          // CHECKOUT
          // ─────────────────────────────────────────────
          case 'checkout.session.completed':
          case 'checkout.session.async_payment_succeeded':
          case 'checkout.session.async_payment_failed': {
            const session = event.data.object;

            const companyId = String(session.client_reference_id || session.metadata?.companyId || '');
            const customerId = asId(session.customer);
            const subId = asId(session.subscription);

            if (!companyId) break;

            const shouldProcess = await markEventProcessedForCompany(companyId, event.id);
            if (!shouldProcess) break;

            if (subId) {
              await syncFromSubscription({
                stripe,
                companyId,
                customerId,
                subscriptionId: subId,
              });
            } else {
              await updateCompany(companyId, { stripeCustomerId: customerId });
            }

            break;
          }

          // ─────────────────────────────────────────────
          // SUBSCRIPTIONS
          // ─────────────────────────────────────────────
          case 'customer.subscription.created':
          case 'customer.subscription.updated': {
            const sub = event.data.object;
            const customerId = asId(sub.customer);

            const companyId = await findCompanyId({
              companyId: sub.metadata?.companyId,
              customerId,
              subscriptionObj: sub,
            });

            if (!companyId) break;

            const shouldProcess = await markEventProcessedForCompany(companyId, event.id);
            if (!shouldProcess) break;

            await syncFromSubscription({
              stripe,
              companyId,
              customerId,
              subscriptionId: sub.id,
            });

            break;
          }

          case 'customer.subscription.deleted': {
            const sub = event.data.object;
            const customerId = asId(sub.customer);

            const companyId = await findCompanyId({
              companyId: sub.metadata?.companyId,
              customerId,
              subscriptionObj: sub,
            });

            if (!companyId) break;

            const shouldProcess = await markEventProcessedForCompany(companyId, event.id);
            if (!shouldProcess) break;

            // ✅ Reseteo limpio
            await updateCompany(companyId, {
              stripeCustomerId: customerId,
              stripeSubscriptionId: null,
              billingStatus: 'none',
              contractedSeats: 1,
              currentPeriodStart: null,
              currentPeriodEnd: null,
            });

            break;
          }

          // ─────────────────────────────────────────────
          // INVOICES
          // ─────────────────────────────────────────────
          case 'invoice.paid': {
            const inv = event.data.object;
            const customerId = asId(inv.customer);

            const companyId = await findCompanyId({ customerId });
            if (!companyId) break;

            const shouldProcess = await markEventProcessedForCompany(companyId, event.id);
            if (!shouldProcess) break;

            await saveInvoice(companyId, inv);

            const subId = asId(inv.subscription);
            if (subId) {
              await syncFromSubscription({
                stripe,
                companyId,
                customerId,
                subscriptionId: subId,
              });
            } else {
              await updateCompany(companyId, { stripeCustomerId: customerId });
            }

            break;
          }

          case 'invoice.payment_failed': {
            const inv = event.data.object;
            const customerId = asId(inv.customer);

            const companyId = await findCompanyId({ customerId });
            if (!companyId) break;

            const shouldProcess = await markEventProcessedForCompany(companyId, event.id);
            if (!shouldProcess) break;

            await saveInvoice(companyId, inv);

            await updateCompany(companyId, {
              stripeCustomerId: customerId,
              billingStatus: 'past_due',
            });

            const subId = asId(inv.subscription);
            if (subId) {
              await syncFromSubscription({
                stripe,
                companyId,
                customerId,
                subscriptionId: subId,
              });
            }

            break;
          }

          default:
            break;
        }

        return res.json({ received: true });
      } catch (e) {
        logger.error('Error manejando webhook', { msg: e?.message, stack: e?.stack });
        return res.status(500).send('Internal error');
      }
    },
);
