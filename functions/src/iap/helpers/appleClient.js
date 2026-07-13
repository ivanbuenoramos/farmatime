const jwt = require('jsonwebtoken');
const logger = require('firebase-functions/logger');
const { BUNDLE_ID, APPLE_API_HOST_PRODUCTION, APPLE_API_HOST_SANDBOX } = require('../../config/iap');

function getPrivateKey() {
  const raw = process.env.APPLE_IAP_PRIVATE_KEY || '';
  if (!raw) throw new Error('APPLE_IAP_PRIVATE_KEY no configurado');
  return raw.replace(/\\n/g, '\n');
}

function buildJwt() {
  const keyId = process.env.APPLE_IAP_KEY_ID;
  const issuerId = process.env.APPLE_IAP_ISSUER_ID;
  if (!keyId || !issuerId) {
    throw new Error('APPLE_IAP_KEY_ID / APPLE_IAP_ISSUER_ID no configurados');
  }

  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: issuerId,
    iat: now,
    exp: now + 60 * 20,
    aud: 'appstoreconnect-v1',
    bid: BUNDLE_ID,
  };

  return jwt.sign(payload, getPrivateKey(), {
    algorithm: 'ES256',
    header: { alg: 'ES256', kid: keyId, typ: 'JWT' },
  });
}

// Decodifica un JWS de App Store sin verificar firma (la firma ya la valida Apple;
// en producción se puede verificar con la cadena de certificados de Apple).
function decodeSignedPayload(signed) {
  if (!signed) return null;
  const decoded = jwt.decode(signed);
  return decoded || null;
}

async function fetchFromApple(url, token) {
  const res = await fetch(url, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: 'application/json',
    },
  });

  if (res.status === 404) return null;
  if (!res.ok) {
    const text = await res.text().catch(() => '');
    // El 401 casi siempre es config de credenciales (key type / keyId /
    // issuerId que no corresponden). Logueamos cuerpo+url para diagnosticar.
    logger.error('[appleClient] Apple API error', {
      status: res.status,
      url,
      body: text?.slice(0, 500),
    });
    const hint = res.status === 401 ?
      ' (revisa APPLE_IAP_KEY_ID / APPLE_IAP_ISSUER_ID / clave .p8: debe ser una clave de tipo In-App Purchase)' :
      '';
    throw new Error(`Apple API ${res.status}: ${text || 'sin cuerpo'}${hint}`);
  }

  return res.json();
}

// Intenta production y, si devuelve "not found" para un transactionId de sandbox, cae a sandbox.
async function getTransactionInfo(transactionId) {
  const token = buildJwt();

  for (const host of [APPLE_API_HOST_PRODUCTION, APPLE_API_HOST_SANDBOX]) {
    const url = `${host}/inApps/v1/transactions/${encodeURIComponent(transactionId)}`;
    try {
      const data = await fetchFromApple(url, token);
      if (data && data.signedTransactionInfo) {
        const payload = decodeSignedPayload(data.signedTransactionInfo);
        if (payload) return { payload, env: host === APPLE_API_HOST_PRODUCTION ? 'production' : 'sandbox' };
      }
    } catch (e) {
      // si no es "not found", propagamos
      if (!String(e?.message || '').includes('404')) throw e;
    }
  }

  return null;
}

async function getSubscriptionStatuses(originalTransactionId) {
  const token = buildJwt();

  for (const host of [APPLE_API_HOST_PRODUCTION, APPLE_API_HOST_SANDBOX]) {
    const url = `${host}/inApps/v1/subscriptions/${encodeURIComponent(originalTransactionId)}`;
    try {
      const data = await fetchFromApple(url, token);
      if (data) return { data, env: host === APPLE_API_HOST_PRODUCTION ? 'production' : 'sandbox' };
    } catch (e) {
      if (!String(e?.message || '').includes('404')) throw e;
    }
  }

  return null;
}

// ───────────────────────────────────────────────────────────────────────────
// Fallback: verifyReceipt con "App-Specific Shared Secret".
//
// Vía alternativa a la App Store Server API. Apple la marca como legacy pero
// sigue operativa, y su credencial (un único string, APPLE_SHARED_SECRET) es
// mucho más simple de configurar que la clave .p8 / keyId / issuerId. Se usa
// cuando la App Store Server API falla (p.ej. 401 por credenciales mal puestas).
// ───────────────────────────────────────────────────────────────────────────
const APPLE_VERIFY_RECEIPT_PRODUCTION = 'https://buy.itunes.apple.com/verifyReceipt';
const APPLE_VERIFY_RECEIPT_SANDBOX = 'https://sandbox.itunes.apple.com/verifyReceipt';

async function postVerifyReceipt(url, payload) {
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  if (!res.ok) throw new Error(`verifyReceipt HTTP ${res.status}`);
  return res.json();
}

// Valida el recibo [receiptData] (base64 del recibo de la app, lo que el
// plugin iOS expone como serverVerificationData) y devuelve la última
// transacción del [productId], o null si no se puede validar / no está
// configurado el shared secret.
async function verifyReceiptFallback(receiptData, productId) {
  const password = process.env.APPLE_SHARED_SECRET;
  if (!password) {
    logger.warn('[appleClient] verifyReceipt fallback no disponible: falta APPLE_SHARED_SECRET');
    return null;
  }
  if (!receiptData) {
    logger.warn('[appleClient] verifyReceipt fallback sin receiptData');
    return null;
  }

  const payload = {
    'receipt-data': receiptData,
    'password': password,
    // NO excluimos transacciones antiguas: queremos TODO el historial para
    // poder encontrar el producto recién comprado (un upgrade/crossgrade puede
    // no aparecer si filtramos solo la última renovación).
    'exclude-old-transactions': false,
  };

  // Apple recomienda probar producción primero y caer a sandbox si status 21007.
  let data = await postVerifyReceipt(APPLE_VERIFY_RECEIPT_PRODUCTION, payload);
  let env = 'production';
  if (data && data.status === 21007) {
    data = await postVerifyReceipt(APPLE_VERIFY_RECEIPT_SANDBOX, payload);
    env = 'sandbox';
  }

  if (!data || data.status !== 0) {
    logger.error('[appleClient] verifyReceipt status no válido', { status: data?.status });
    return null;
  }

  // Defensa: el recibo debe ser de NUESTRA app (no confiar solo en el shared
  // secret). receipt.bundle_id es el bundle de la app que generó el recibo.
  const bundleId = data.receipt?.bundle_id;
  if (bundleId && bundleId !== BUNDLE_ID) {
    logger.error('[appleClient] verifyReceipt bundleId no coincide', { bundleId });
    return null;
  }

  // Buscamos la transacción del producto en TODAS las fuentes del recibo:
  //  - latest_receipt_info: renovaciones de suscripciones auto-renovables.
  //  - receipt.in_app: transacciones del propio recibo de la app.
  // (la compra recién hecha puede aparecer en cualquiera de las dos).
  const latestInfo = Array.isArray(data.latest_receipt_info) ? data.latest_receipt_info : [];
  const inApp = Array.isArray(data.receipt?.in_app) ? data.receipt.in_app : [];
  const allTx = [...latestInfo, ...inApp];

  // SEGURIDAD: solo aceptamos transacciones del producto EXACTO solicitado
  // (no caemos a "cualquier otro producto del recibo").
  const forProduct = allTx
      .filter((i) => i.product_id === productId)
      .sort((a, b) => Number(b.purchase_date_ms || 0) - Number(a.purchase_date_ms || 0));
  const latest = forProduct[0];
  if (!latest) {
    const presentes = [...new Set(allTx.map((i) => i.product_id))];
    logger.warn('[appleClient] verifyReceipt: productId no encontrado en el recibo', {
      productId,
      productosEnRecibo: presentes,
      env,
    });
    return null;
  }

  const expiresAtMs = Number(latest.expires_date_ms) || null;
  const status = expiresAtMs && expiresAtMs > Date.now() ? 'active' : 'expired';

  const pri = Array.isArray(data.pending_renewal_info) ?
    data.pending_renewal_info.find((p) => p.product_id === productId) :
    null;
  const autoRenewing = pri ? pri.auto_renew_status === '1' : true;

  return {
    productId: latest.product_id,
    status,
    expiresAtMs,
    purchaseDateMs: Number(latest.purchase_date_ms) || null,
    originalTransactionId: String(latest.original_transaction_id || ''),
    autoRenewing,
    env,
  };
}

// Extrae la última transacción renovable de la respuesta de subscriptions.
function extractLatestTransaction(statusesResponse) {
  if (!statusesResponse?.data) return null;
  const groups = statusesResponse.data.data || [];
  for (const group of groups) {
    const items = group.lastTransactions || [];
    if (items.length > 0) {
      const item = items[0];
      return {
        status: item.status,
        signedTransactionInfo: decodeSignedPayload(item.signedTransactionInfo),
        signedRenewalInfo: decodeSignedPayload(item.signedRenewalInfo),
      };
    }
  }
  return null;
}

module.exports = {
  buildJwt,
  decodeSignedPayload,
  getTransactionInfo,
  getSubscriptionStatuses,
  extractLatestTransaction,
  verifyReceiptFallback,
};
