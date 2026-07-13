// Diagnóstico de credenciales App Store Server API (IAP) — NO toca producción.
//
// Construye el MISMO JWT que usa src/iap/helpers/appleClient.js y llama a la
// App Store Server API. Sirve para validar APPLE_IAP_KEY_ID / ISSUER_ID / .p8
// SIN tener que redesplegar ni configurar secrets.
//
// Interpretación del resultado:
//   - HTTP 401  -> credenciales INVÁLIDAS (key type / keyId / issuerId / .p8
//                  no corresponden). Es el error actual en producción.
//   - HTTP 404  -> credenciales VÁLIDAS (el JWT se aceptó); solo que ese
//                  transactionId no existe. ¡Es lo que queremos ver!
//   - HTTP 200  -> credenciales VÁLIDAS y la transacción existe.
//
// Uso:
//   APPLE_IAP_KEY_ID=XXXXXXXXXX \
//   APPLE_IAP_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
//   node scripts/check_apple_iap.js /ruta/a/AuthKey_XXXX.p8 [transactionId]
//
// (transactionId es opcional; con cualquier valor sirve para distinguir
//  401 vs 404. Si tienes uno real de un sandbox, mejor.)

const fs = require('fs');
const jwt = require('jsonwebtoken');

const BUNDLE_ID = 'net.farmatime.app';
const HOSTS = {
  production: 'https://api.storekit.itunes.apple.com',
  sandbox: 'https://api.storekit-sandbox.itunes.apple.com',
};

function fail(msg) {
  console.error('❌ ' + msg);
  process.exit(1);
}

const keyPath = process.argv[2];
const transactionId = process.argv[3] || '0';
const keyId = process.env.APPLE_IAP_KEY_ID;
const issuerId = process.env.APPLE_IAP_ISSUER_ID;

if (!keyPath) fail('Falta la ruta al .p8. Uso: node scripts/check_apple_iap.js /ruta/AuthKey_XXXX.p8 [transactionId]');
if (!keyId) fail('Falta env APPLE_IAP_KEY_ID');
if (!issuerId) fail('Falta env APPLE_IAP_ISSUER_ID');
if (!fs.existsSync(keyPath)) fail('No existe el archivo .p8: ' + keyPath);

const privateKey = fs.readFileSync(keyPath, 'utf8');

console.log('— Diagnóstico App Store Server API —');
console.log('keyId:', keyId, '| len', keyId.length, '(esperado 10)');
console.log('issuerId:', issuerId.slice(0, 8) + '-…', '| formato UUID:',
    /^[0-9a-fA-F-]{36}$/.test(issuerId));
console.log('.p8 BEGIN/END:',
    privateKey.includes('BEGIN PRIVATE KEY') && privateKey.includes('END PRIVATE KEY'));
console.log('bundleId:', BUNDLE_ID);
console.log('');

const now = Math.floor(Date.now() / 1000);
let token;
try {
  token = jwt.sign(
      { iss: issuerId, iat: now, exp: now + 60 * 20, aud: 'appstoreconnect-v1', bid: BUNDLE_ID },
      privateKey,
      { algorithm: 'ES256', header: { alg: 'ES256', kid: keyId, typ: 'JWT' } },
  );
} catch (e) {
  fail('jwt.sign falló (el .p8 no es una clave EC válida): ' + e.message);
}
console.log('JWT generado OK (length', token.length + ')\n');

(async () => {
  for (const [env, host] of Object.entries(HOSTS)) {
    const url = `${host}/inApps/v1/transactions/${encodeURIComponent(transactionId)}`;
    try {
      const res = await fetch(url, {
        headers: { Authorization: `Bearer ${token}`, Accept: 'application/json' },
      });
      const body = await res.text().catch(() => '');
      let verdict;
      if (res.status === 401) verdict = '❌ 401 → CREDENCIALES INVÁLIDAS';
      else if (res.status === 404) verdict = '✅ 404 → credenciales VÁLIDAS (tx no encontrada, normal)';
      else if (res.ok) verdict = '✅ 200 → credenciales VÁLIDAS y tx encontrada';
      else verdict = `⚠️ ${res.status}`;
      console.log(`[${env}] ${verdict}`);
      if (res.status !== 404 && body) console.log(`        body: ${body.slice(0, 300)}`);
    } catch (e) {
      console.log(`[${env}] error de red: ${e.message}`);
    }
  }
})();
