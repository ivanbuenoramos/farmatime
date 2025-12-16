// src/helpers/stripeRaw.js
const https = require('https');

function toFormUrlEncoded(obj) {
  const pairs = [];

  function add(key, value) {
    if (value === undefined || value === null) return;
    pairs.push(`${encodeURIComponent(key)}=${encodeURIComponent(String(value))}`);
  }

  function walk(prefix, value) {
    if (value === undefined || value === null) return;

    if (Array.isArray(value)) {
      value.forEach((v, i) => {
        // Stripe acepta array indexado con [0], [1]...
        walk(`${prefix}[${i}]`, v);
      });
      return;
    }

    if (typeof value === 'object') {
      Object.keys(value).forEach((k) => {
        walk(`${prefix}[${k}]`, value[k]);
      });
      return;
    }

    add(prefix, value);
  }

  Object.keys(obj || {}).forEach((k) => walk(k, obj[k]));
  return pairs.join('&');
}

function getStripeSecretKey() {
  // En Cloud Functions v2, secrets llegan como env vars también
  const key = String(process.env.STRIPE_SECRET_KEY || '').trim();
  if (!key) {
    throw new Error('Missing STRIPE_SECRET_KEY');
  }
  return key;
}

function stripePost(path, params) {
  const secretKey = getStripeSecretKey();

  const body = toFormUrlEncoded(params || {});
  const options = {
    method: 'POST',
    hostname: 'api.stripe.com',
    path,
    headers: {
      'Authorization': `Bearer ${secretKey}`,
      'Content-Type': 'application/x-www-form-urlencoded',
      'Content-Length': Buffer.byteLength(body),
    },
  };

  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let raw = '';
      res.on('data', (chunk) => (raw += chunk));
      res.on('end', () => {
        let json;
        try {
          json = raw ? JSON.parse(raw) : {};
        } catch (e) {
          return reject(new Error(`Stripe RAW invalid JSON: ${raw}`));
        }

        if (res.statusCode >= 200 && res.statusCode < 300) {
          return resolve(json);
        }

        const msg =
          json?.error?.message ||
          `Stripe RAW error ${res.statusCode}: ${raw}`;

        reject(new Error(msg));
      });
    });

    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

async function retrieveUpcomingInvoiceRaw(params) {
  return stripePost('/v1/invoices/upcoming', params);
}

module.exports = { retrieveUpcomingInvoiceRaw };
