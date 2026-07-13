// googlePlayNotifications.js
// Google Play Real-time Developer Notifications (RTDN).
// Se reciben vía Pub/Sub topic configurado en Play Console.
const { onMessagePublished } = require('firebase-functions/v2/pubsub');
const logger = require('firebase-functions/logger');
const { getSubscriptionV2 } = require('./helpers/googleClient');
const { getPlan } = require('./helpers/planCatalog');
const {
  updateCompanyMirror,
  markCompanyAsCanceled,
  getCompanyIdFromPurchaseToken,
} = require('../helpers/companyMirror');
const { updateEmployeesForBillingState } = require('../helpers/billingEmployees');

// OJO: Pub/Sub prohíbe nombres de topic que empiecen por "goog".
const RTDN_TOPIC = process.env.GOOGLE_PLAY_PUBSUB_TOPIC || 'play-rtdn-notifications';

// SubscriptionNotificationType (RTDN):
//   12 = SUBSCRIPTION_REVOKED (reembolso / chargeback)
//   13 = SUBSCRIPTION_EXPIRED (expiración; también la emite Google para el
//        token VIEJO al reemplazar una suscripción en un cambio de plan)
// Ref: https://developer.android.com/google/play/billing/rtdn-reference
const NOTIFICATION_TYPE_REVOKED = 12;

// VoidedPurchaseNotification.productType:
//   1 = PRODUCT_TYPE_SUBSCRIPTION, 2 = PRODUCT_TYPE_ONE_TIME
const VOIDED_PRODUCT_TYPE_SUBSCRIPTION = 1;

function mapGoogleState(state) {
  switch (state) {
    case 'SUBSCRIPTION_STATE_ACTIVE': return 'active';
    case 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD': return 'in_grace_period';
    case 'SUBSCRIPTION_STATE_ON_HOLD': return 'on_hold';
    case 'SUBSCRIPTION_STATE_PAUSED': return 'paused';
    case 'SUBSCRIPTION_STATE_CANCELED': return 'canceled';
    case 'SUBSCRIPTION_STATE_EXPIRED': return 'expired';
    case 'SUBSCRIPTION_STATE_PENDING': return 'pending';
    default: return 'none';
  }
}

exports.iap_googlePlayNotifications = onMessagePublished(
    { region: 'europe-west1', topic: RTDN_TOPIC },
    async (event) => {
      try {
        const data = event.data?.message?.json ||
          JSON.parse(Buffer.from(event.data?.message?.data || '', 'base64').toString('utf8'));

        if (!data) {
          logger.warn('[googleNotif] mensaje vacío');
          return;
        }

        logger.info('[googleNotif]', { data });

        // Reembolso anulado vía Voided Purchases API: llega SIN
        // subscriptionNotification, pero trae purchaseToken. Debe revocar las
        // plazas igual que un SUBSCRIPTION_REVOKED, o el reembolso dejaría a
        // la empresa con el plan activo sin haberlo pagado.
        const voided = data.voidedPurchaseNotification;
        if (voided) {
          if (voided.productType &&
              voided.productType !== VOIDED_PRODUCT_TYPE_SUBSCRIPTION) {
            // Solo vendemos suscripciones; un voided de one-time no es nuestro.
            return;
          }
          const companyId =
              await getCompanyIdFromPurchaseToken(voided.purchaseToken);
          if (!companyId) {
            logger.warn('[googleNotif] voidedPurchase sin empresa vinculada', {
              orderId: voided.orderId || null,
            });
            return;
          }
          await markCompanyAsCanceled(companyId, 'revoked', {
            ifPurchaseTokenMatches: voided.purchaseToken,
          });
          await updateEmployeesForBillingState(companyId);
          return;
        }

        const subNotif = data.subscriptionNotification;
        if (!subNotif) {
          // test notifications: no acción
          return;
        }

        const purchaseToken = subNotif.purchaseToken;
        const productId = subNotif.subscriptionId;
        const notificationType = subNotif.notificationType;

        const companyId = await getCompanyIdFromPurchaseToken(purchaseToken);
        if (!companyId) {
          logger.warn('[googleNotif] companyId no encontrado', { purchaseToken });
          return;
        }

        // Una revocación (reembolso/chargeback) se notifica por tipo, no siempre
        // se refleja en subscriptionState, así que la tratamos antes de consultar
        // el estado para no perderla.
        if (notificationType === NOTIFICATION_TYPE_REVOKED) {
          await markCompanyAsCanceled(companyId, 'revoked', {
            ifPurchaseTokenMatches: purchaseToken,
          });
          await updateEmployeesForBillingState(companyId);
          return;
        }

        const subInfo = await getSubscriptionV2(purchaseToken);
        if (!subInfo) {
          logger.warn('[googleNotif] subscription no encontrada en Play');
          return;
        }

        const status = mapGoogleState(subInfo.subscriptionState);

        if (status === 'expired' || status === 'canceled' || status === 'revoked') {
          // Preservamos contexto + canceledAt para el periodo de gracia in-app.
          // La guarda por token evita que la notificación del token VIEJO de un
          // cambio de plan cancele a una empresa que acaba de pagar el nuevo.
          await markCompanyAsCanceled(companyId, status, {
            ifPurchaseTokenMatches: purchaseToken,
          });
          await updateEmployeesForBillingState(companyId);
          return;
        }

        const plan = getPlan(productId);
        if (!plan) {
          logger.warn('[googleNotif] productId no está en catálogo', { productId });
          return;
        }

        const line = (subInfo.lineItems || []).find((li) => li.productId === productId) || subInfo.lineItems?.[0];
        const expiresAtMs = line?.expiryTime ? Date.parse(line.expiryTime) : null;
        const startMs = subInfo.startTime ? Date.parse(subInfo.startTime) : null;
        const autoRenewing = !!line?.autoRenewingPlan;

        await updateCompanyMirror(companyId, {
          platform: 'android',
          productId,
          status,
          totalSeats: plan.totalSeats,
          purchaseToken,
          expiresAtMs,
          currentPeriodStartMs: startMs,
          autoRenewing,
          environment: subInfo.testPurchase ? 'sandbox' : 'production',
        }, { ifPurchaseTokenMatches: purchaseToken });
        await updateEmployeesForBillingState(companyId);
      } catch (e) {
        logger.error('[googleNotif] error', { msg: e?.message, stack: e?.stack });
      }
    },
);
