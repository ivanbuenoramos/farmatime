// verifyPurchase.js
// Callable llamado por la app tras una compra para validar el recibo contra
// la store y persistir el estado de suscripción en Firestore.
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
const { assertAuth, assertCompanyAccount } = require('../helpers/assertions');
const {
  updateCompanyMirror,
  getCompanyIdFromOriginalTransactionId,
  getCompanyIdFromPurchaseToken,
} = require('../helpers/companyMirror');
const { updateEmployeesForBillingState } = require('../helpers/billingEmployees');
const { getPlan, isKnownProduct } = require('./helpers/planCatalog');
const appleClient = require('./helpers/appleClient');
const googleClient = require('./helpers/googleClient');

function mapAppleStatus(status) {
  switch (status) {
    case 1: return 'active';
    case 2: return 'expired';
    case 3: return 'in_billing_retry';
    case 4: return 'in_grace_period';
    case 5: return 'revoked';
    default: return 'none';
  }
}

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

// Impide que una suscripción de la tienda (atada al Apple ID / cuenta de
// Google) se vincule a MÁS de una empresa de farmatime. Si ya pertenece a otra
// empresa, rechazamos: es el caso de "restaurar compras" con la misma cuenta de
// App Store estando logueado en una empresa distinta. Cada suscripción de la
// tienda = una sola empresa.
async function assertNotClaimedByOther({ companyId, originalTransactionId, purchaseToken }) {
  let owner = '';
  if (originalTransactionId) {
    owner = await getCompanyIdFromOriginalTransactionId(originalTransactionId);
  }
  if (!owner && purchaseToken) {
    owner = await getCompanyIdFromPurchaseToken(purchaseToken);
  }
  if (owner && owner !== companyId) {
    logger.warn('[verifyPurchase] suscripción ya vinculada a otra empresa', {
      owner, companyId, originalTransactionId: originalTransactionId || null,
    });
    throw new HttpsError(
        'failed-precondition',
        'Esta suscripción de la App Store ya está vinculada a otra cuenta de ' +
        'farmatime. Usa otra cuenta de App Store o gestiona la suscripción ' +
        'existente desde la cuenta que la contrató.',
    );
  }
}

// Sanea la lista de uids que el admin eligió desactivar en un downgrade:
// solo strings no vacíos, sin duplicados, con un tope defensivo.
function sanitizeDisableUids(raw) {
  if (!Array.isArray(raw)) return [];
  const uids = raw
      .filter((u) => typeof u === 'string' && u.trim().length > 0)
      .map((u) => u.trim());
  return [...new Set(uids)].slice(0, 100);
}

// Camino principal: App Store Server API (requiere clave In-App Purchase).
async function verifyIosViaServerApi({ companyId, productId, transactionId, disableUids }) {
  if (!transactionId) throw new HttpsError('invalid-argument', 'transactionId requerido');

  const txResult = await appleClient.getTransactionInfo(transactionId);
  if (!txResult) throw new HttpsError('not-found', 'Transacción no encontrada en App Store');

  const tx = txResult.payload;
  const env = txResult.env;
  const bundleOk = tx.bundleId === 'net.farmatime.app';
  if (!bundleOk) throw new HttpsError('permission-denied', 'bundleId inválido');
  if (tx.productId !== productId) {
    throw new HttpsError('invalid-argument', `productId del recibo (${tx.productId}) no coincide con ${productId}`);
  }

  const originalTransactionId = String(tx.originalTransactionId || transactionId);

  const statuses = await appleClient.getSubscriptionStatuses(originalTransactionId);
  const latest = appleClient.extractLatestTransaction(statuses);

  const plan = getPlan(productId);
  if (!plan) throw new HttpsError('invalid-argument', 'Producto desconocido');

  // Si la consulta a getSubscriptionStatuses no devuelve el estado actual de
  // la suscripción NO asumimos 'active' (eso permitía marcar como pagada una
  // suscripción que en realidad no lo estaba). Sin estado fiable, abortamos y
  // que el cliente reintente.
  if (!latest) {
    throw new HttpsError(
        'unavailable',
        'No se pudo determinar el estado de la suscripción. Inténtalo de nuevo.',
    );
  }
  const status = mapAppleStatus(latest.status);
  const expiresAtMs = Number(tx.expiresDate) || (latest?.signedTransactionInfo?.expiresDate) || null;
  const purchaseDateMs = Number(tx.purchaseDate) || null;
  const autoRenewing = !!(latest?.signedRenewalInfo?.autoRenewStatus);

  await assertNotClaimedByOther({ companyId, originalTransactionId });

  await updateCompanyMirror(companyId, {
    platform: 'ios',
    productId,
    status,
    totalSeats: plan.totalSeats,
    originalTransactionId,
    // Al pagar en iOS limpiamos el token de Android: si quedara, una RTDN
    // tardía de Google (p.ej. EXPIRED del ciclo anterior) seguiría resolviendo
    // esta empresa y podría cancelarla aunque acabe de pagar en Apple.
    purchaseToken: null,
    expiresAtMs,
    currentPeriodStartMs: purchaseDateMs,
    autoRenewing,
    environment: env,
  });
  // Re-evaluamos las plazas/empleados con el nuevo plan (downgrade/upgrade),
  // respetando a quién eligió desactivar el admin.
  await updateEmployeesForBillingState(companyId, { preferDisableUids: disableUids });

  return { status, totalSeats: plan.totalSeats, expiresAtMs };
}

// Fallback: verifyReceipt con App-Specific Shared Secret (APPLE_SHARED_SECRET).
async function verifyIosViaReceipt({ companyId, productId, receiptData, disableUids }) {
  const fb = await appleClient.verifyReceiptFallback(receiptData, productId);
  if (!fb) return null;

  // SEGURIDAD: el recibo debe contener exactamente el producto solicitado.
  if (fb.productId !== productId) {
    throw new HttpsError(
        'invalid-argument',
        `productId del recibo (${fb.productId}) no coincide con ${productId}`,
    );
  }

  const plan = getPlan(productId);
  if (!plan) throw new HttpsError('invalid-argument', 'Producto desconocido');

  await assertNotClaimedByOther({
    companyId,
    originalTransactionId: fb.originalTransactionId,
  });

  await updateCompanyMirror(companyId, {
    platform: 'ios',
    productId,
    status: fb.status,
    totalSeats: plan.totalSeats,
    originalTransactionId: fb.originalTransactionId,
    // Ver comentario en verifyIosViaServerApi: sin token android obsoleto.
    purchaseToken: null,
    expiresAtMs: fb.expiresAtMs,
    currentPeriodStartMs: fb.purchaseDateMs,
    autoRenewing: fb.autoRenewing,
    environment: fb.env,
  });
  await updateEmployeesForBillingState(companyId, { preferDisableUids: disableUids });

  return { status: fb.status, totalSeats: plan.totalSeats, expiresAtMs: fb.expiresAtMs };
}

async function verifyIos({ companyId, productId, transactionId, receiptData, disableUids }) {
  // 1) Camino preferido: App Store Server API.
  try {
    if (transactionId) {
      return await verifyIosViaServerApi({ companyId, productId, transactionId, disableUids });
    }
  } catch (e) {
    // Errores "definitivos" del recibo (no de credenciales) se propagan tal cual.
    if (e instanceof HttpsError &&
        (e.code === 'permission-denied' || e.code === 'invalid-argument')) {
      throw e;
    }
    logger.warn('[verifyIos] App Store Server API falló; intentando verifyReceipt', {
      code: e?.code,
      message: e?.message,
    });
  }

  // 2) Fallback: verifyReceipt con shared secret.
  const viaReceipt = await verifyIosViaReceipt({ companyId, productId, receiptData, disableUids });
  if (viaReceipt) return viaReceipt;

  throw new HttpsError(
      'unavailable',
      'No se pudo verificar la compra con Apple. Revisa las credenciales de la ' +
      'App Store Server API (clave In-App Purchase) o configura APPLE_SHARED_SECRET.',
  );
}

async function verifyAndroid({ companyId, productId, purchaseToken, disableUids }) {
  if (!purchaseToken) throw new HttpsError('invalid-argument', 'purchaseToken requerido');

  const subInfo = await googleClient.getSubscriptionV2(purchaseToken);
  if (!subInfo) throw new HttpsError('not-found', 'Suscripción no encontrada en Google Play');

  // Google devuelve lineItems: validamos que el productId coincide.
  const line = (subInfo.lineItems || []).find((li) => li.productId === productId);
  if (!line) {
    throw new HttpsError('invalid-argument', `productId ${productId} no presente en la suscripción`);
  }

  const plan = getPlan(productId);
  if (!plan) throw new HttpsError('invalid-argument', 'Producto desconocido');

  const status = mapGoogleState(subInfo.subscriptionState);
  const expiresAtMs = line.expiryTime ? Date.parse(line.expiryTime) : null;
  const startMs = subInfo.startTime ? Date.parse(subInfo.startTime) : null;
  const autoRenewing = !!line.autoRenewingPlan;

  await assertNotClaimedByOther({ companyId, purchaseToken });

  // Acknowledge obligatorio por Google (si no, Google reembolsa en 3 días).
  try {
    await googleClient.acknowledgeSubscription(productId, purchaseToken);
  } catch (e) {
    logger.warn('[verifyPurchase] acknowledge falló', { msg: e?.message });
  }

  await updateCompanyMirror(companyId, {
    platform: 'android',
    productId,
    status,
    totalSeats: plan.totalSeats,
    purchaseToken,
    // Simétrico a verifyIos: al pagar en Android limpiamos el identificador de
    // Apple para que una notificación tardía del App Store no matchee esta
    // empresa por una suscripción iOS ya abandonada.
    originalTransactionId: null,
    expiresAtMs,
    currentPeriodStartMs: startMs,
    autoRenewing,
    environment: subInfo.testPurchase ? 'sandbox' : 'production',
  });
  await updateEmployeesForBillingState(companyId, { preferDisableUids: disableUids });

  return { status, totalSeats: plan.totalSeats, expiresAtMs };
}

exports.iap_verifyPurchase = onCall(
    { region: 'europe-west1' },
    async (req) => {
      assertAuth(req);
      const { companyId, platform, productId } = req.data || {};
      await assertCompanyAccount(req.auth.uid, companyId);

      if (!isKnownProduct(productId)) {
        throw new HttpsError('invalid-argument', `productId no válido: ${productId}`);
      }

      // Uids que el admin eligió desactivar en un downgrade (opcional).
      const disableUids = sanitizeDisableUids(req.data.disableUids);

      logger.info('[iap_verifyPurchase]', {
        companyId, platform, productId,
        disableUids: disableUids.length ? disableUids : undefined,
      });

      try {
        if (platform === 'ios') {
          return await verifyIos({
            companyId,
            productId,
            transactionId: String(req.data.transactionId || '').trim(),
            receiptData: String(req.data.receiptData || '').trim(),
            disableUids,
          });
        }

        if (platform === 'android') {
          return await verifyAndroid({
            companyId,
            productId,
            purchaseToken: String(req.data.purchaseToken || '').trim(),
            disableUids,
          });
        }

        throw new HttpsError('invalid-argument', `platform no soportada: ${platform}`);
      } catch (e) {
        // Los HttpsError ya llevan código y mensaje útiles: se propagan tal cual.
        if (e instanceof HttpsError) throw e;
        // Cualquier otro Error se devolvía como "INTERNAL" opaco. Lo logueamos
        // completo y lo reenviamos con el motivo real para poder diagnosticar
        // (p.ej. "Apple API 401: JWT inválido").
        logger.error('[iap_verifyPurchase] error no controlado', {
          companyId,
          platform,
          productId,
          message: e?.message,
          stack: e?.stack,
        });
        throw new HttpsError(
            'internal',
            e?.message || 'Error verificando la compra',
        );
      }
    },
);
