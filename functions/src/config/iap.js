// Configuración IAP compartida.
const BUNDLE_ID = 'net.farmatime.app';
const ANDROID_PACKAGE = 'net.farmatime.app';

// App Store Server API environment. En producción cambiar a 'production'.
// Apple enruta automáticamente a sandbox si el recibo es de sandbox (status 21007),
// pero hay que configurar la URL base correcta para polling/lookup.
const APPLE_API_HOST_PRODUCTION = 'https://api.storekit.itunes.apple.com';
const APPLE_API_HOST_SANDBOX = 'https://api.storekit-sandbox.itunes.apple.com';

function getAppleApiHost() {
  const env = String(process.env.APPLE_ENV || 'sandbox').toLowerCase();
  return env === 'production' ? APPLE_API_HOST_PRODUCTION : APPLE_API_HOST_SANDBOX;
}

module.exports = {
  BUNDLE_ID,
  ANDROID_PACKAGE,
  APPLE_API_HOST_PRODUCTION,
  APPLE_API_HOST_SANDBOX,
  getAppleApiHost,
};
