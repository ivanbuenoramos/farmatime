const { GoogleAuth } = require('google-auth-library');
const { google } = require('googleapis');
const { ANDROID_PACKAGE } = require('../../config/iap');

let cachedClient = null;

async function getAndroidPublisher() {
  if (cachedClient) return cachedClient;

  const raw = process.env.GOOGLE_PLAY_SERVICE_ACCOUNT || '';
  if (!raw) throw new Error('GOOGLE_PLAY_SERVICE_ACCOUNT no configurado');

  let credentials;
  try {
    credentials = JSON.parse(raw);
  } catch (e) {
    throw new Error('GOOGLE_PLAY_SERVICE_ACCOUNT no es JSON válido');
  }

  const auth = new GoogleAuth({
    credentials,
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });

  cachedClient = google.androidpublisher({ version: 'v3', auth });
  return cachedClient;
}

async function getSubscriptionV2(purchaseToken) {
  const publisher = await getAndroidPublisher();
  const res = await publisher.purchases.subscriptionsv2.get({
    packageName: ANDROID_PACKAGE,
    token: purchaseToken,
  });
  return res.data;
}

async function acknowledgeSubscription(productId, purchaseToken) {
  const publisher = await getAndroidPublisher();
  try {
    await publisher.purchases.subscriptions.acknowledge({
      packageName: ANDROID_PACKAGE,
      subscriptionId: productId,
      token: purchaseToken,
      requestBody: {},
    });
    return true;
  } catch (e) {
    // Ya reconocido, ignorar
    const code = e?.code || e?.response?.status;
    if (code === 400) return true;
    throw e;
  }
}

module.exports = {
  getAndroidPublisher,
  getSubscriptionV2,
  acknowledgeSubscription,
};
