// functions/src/notifications/onBillingStatusChange.js
//
// Trigger: cambia el estado de facturación de una empresa.
//   companies/{companyId}   (campo top-level `billingStatus`)
//
// El destinatario es siempre la EMPRESA (el id del doc = uid de la farmacia).
// Cubre las transiciones relevantes de billingStatus:
//   → in_grace_period / in_billing_retry : pago fallido, reintentando.
//   → on_hold / paused                   : suscripción retenida/pausada.
//   → canceled / expired / revoked       : suscripción terminada (gracia 30 días).
//   (no pagado) → active                 : suscripción activada/restaurada.

const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { logger } = require('firebase-functions');
const { sendPushToUsers } = require('./sendPush');

const PAID = new Set(['active', 'trialing']);
const RETRY = new Set(['in_grace_period', 'in_billing_retry']);
const HELD = new Set(['on_hold', 'paused']);
const ENDED = new Set(['canceled', 'expired', 'revoked']);

/**
 * Texto de notificación según el nuevo estado (o null si no se notifica).
 * @param {string} status   nuevo billingStatus
 * @param {string} prev     billingStatus anterior
 * @return {?{title: string, body: string}}
 */
function messageForStatus(status, prev) {
  if (RETRY.has(status)) {
    return {
      title: 'Problema con el pago',
      body: 'No se pudo renovar tu suscripción. Revisa tu método de pago para ' +
        'evitar interrupciones.',
    };
  }
  if (HELD.has(status)) {
    return {
      title: 'Suscripción retenida',
      body: 'Tu suscripción está retenida. Resuélvelo en la tienda (App Store / ' +
        'Google Play) para que tus empleados sigan trabajando.',
    };
  }
  if (ENDED.has(status)) {
    return {
      title: 'Suscripción finalizada',
      body: 'Tu suscripción ha terminado. Tienes 30 días para renovarla antes de ' +
        'que tus empleados pierdan el acceso.',
    };
  }
  if (PAID.has(status) && !PAID.has(prev)) {
    // Solo notificamos la activación si veníamos de un estado no pagado.
    return {
      title: '¡Suscripción activa!',
      body: 'Tu suscripción está activa. Tus empleados pueden trabajar sin ' +
        'interrupciones.',
    };
  }
  return null;
}

exports.onBillingStatusChange = onDocumentWritten(
    'companies/{companyId}',
    async (event) => {
      const before = event.data?.before?.data() || null;
      const after = event.data?.after?.data() || null;

      if (!after) return; // empresa borrada: no notificamos

      const prev = (before && before.billingStatus) || 'none';
      const status = after.billingStatus || 'none';

      // Solo nos interesa el cambio real de estado de facturación.
      if (prev === status) return;

      const msg = messageForStatus(status, prev);
      if (!msg) return;

      const companyId = event.params.companyId;
      await sendPushToUsers({
        uids: [companyId],
        title: msg.title,
        body: msg.body,
        data: { type: 'billing', billingStatus: status },
      });

      logger.info(
          `onBillingStatusChange: ${prev} → ${status} · empresa ${companyId}`,
      );
    },
);
