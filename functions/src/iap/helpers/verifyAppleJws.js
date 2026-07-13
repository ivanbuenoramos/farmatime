// verifyAppleJws.js
// Verificación de firma de los JWS de App Store Server Notifications v2.
//
// Las notificaciones (signedPayload, signedTransactionInfo, signedRenewalInfo)
// llegan a un endpoint HTTP público SIN autenticación, así que NO basta con
// decodificarlas: hay que verificar que están firmadas por Apple. Cada JWS lleva
// en su cabecera la cadena de certificados X.509 (campo `x5c`); verificamos:
//   1. Que la cadena encadena hasta el Apple Root CA - G3 (pin embebido).
//   2. Que cada certificado está firmado por el siguiente de la cadena.
//   3. Que la firma del JWS es válida contra la clave pública del certificado hoja.
//
// Ref: https://developer.apple.com/documentation/appstoreservernotifications/responsebodyv2
const crypto = require('crypto');
const forge = require('node-forge');
const { importX509, compactVerify } = require('jose');

// Apple Root CA - G3 (https://www.apple.com/certificateauthority/).
// Es el ancla de confianza de la cadena de los JWS de App Store.
// Fingerprint SHA-256 publicado por Apple:
//   63:34:3A:BF:B8:9A:6A:03:EB:B5:7E:9B:3F:5F:A7:BE:7C:4F:5C:75:6F:30:17:B3:A8:C4:88:C3:65:3E:91:79
const APPLE_ROOT_CA_G3_SHA256 =
  '63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179';

function derToForgeCert(derBase64) {
  const der = forge.util.decode64(derBase64);
  const asn1 = forge.asn1.fromDer(der);
  return forge.pki.certificateFromAsn1(asn1);
}

function certSha256(derBase64) {
  const der = Buffer.from(derBase64, 'base64');
  return crypto.createHash('sha256').update(der).digest('hex');
}

function decodeProtectedHeader(jws) {
  const headerB64 = String(jws).split('.')[0];
  const json = Buffer.from(headerB64, 'base64').toString('utf8');
  return JSON.parse(json);
}

// Verifica que la cadena x5c es válida y encadena hasta el Apple Root CA - G3.
function verifyCertificateChain(x5c) {
  if (!Array.isArray(x5c) || x5c.length < 2) {
    throw new Error('x5c ausente o cadena incompleta');
  }

  // Apple envía la cadena hoja → intermedio → raíz.
  const root = x5c[x5c.length - 1];
  if (certSha256(root) !== APPLE_ROOT_CA_G3_SHA256) {
    throw new Error('la raíz de la cadena no es el Apple Root CA - G3');
  }

  const certs = x5c.map(derToForgeCert);
  const now = new Date();

  for (let i = 0; i < certs.length; i++) {
    const cert = certs[i];
    if (now < cert.validity.notBefore || now > cert.validity.notAfter) {
      throw new Error('certificado de la cadena fuera de vigencia');
    }
    // Cada certificado debe estar firmado por el siguiente (el último es raíz
    // autofirmada, ya anclada por el pin SHA-256).
    const issuer = certs[i + 1];
    if (issuer && !issuer.verify(cert)) {
      throw new Error('eslabón de la cadena de certificados inválido');
    }
  }
}

// Verifica la firma de un JWS de Apple y devuelve su payload decodificado.
// Lanza si la firma o la cadena de certificados no son válidas.
async function verifyAppleJws(jws) {
  if (!jws) throw new Error('JWS vacío');

  const header = decodeProtectedHeader(jws);
  // Apple firma con ES256. Forzamos el algoritmo en lugar de tomarlo del header
  // (un atacante podría declarar 'none' o un algoritmo más débil).
  if (header.alg !== 'ES256') {
    throw new Error(`alg inválido: ${header.alg} (se requiere ES256)`);
  }
  const x5c = header.x5c;
  verifyCertificateChain(x5c);

  // El certificado hoja (primero de la cadena) contiene la clave pública con la
  // que se firmó el JWS.
  const leafPem = `-----BEGIN CERTIFICATE-----\n${x5c[0]}\n-----END CERTIFICATE-----`;
  const publicKey = await importX509(leafPem, 'ES256');

  const { payload } = await compactVerify(jws, publicKey, {
    algorithms: ['ES256'],
  });
  return JSON.parse(Buffer.from(payload).toString('utf8'));
}

module.exports = { verifyAppleJws, APPLE_ROOT_CA_G3_SHA256 };
