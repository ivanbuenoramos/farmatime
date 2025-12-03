const { setGlobalOptions } = require('firebase-functions/v2');
setGlobalOptions({
  region: 'europe-west1',
  secrets: ['STRIPE_SECRET', 'PRICE_ID', 'STRIPE_WEBHOOK_SECRET'],
});

// --- STRIPE ---
exports.stripe_createCustomerAndSubscription = require('./src/stripe/createCustomerAndSubscription').stripe_createCustomerAndSubscription;
// (haz lo mismo con cada archivo en /stripe)
exports.stripe_updateSubscriptionQuantity = require('./src/stripe/updateSubscriptionQuantity').stripe_updateSubscriptionQuantity;
exports.stripe_createBillingPortalSession = require('./src/stripe/createBillingPortalSession').stripe_createBillingPortalSession;
exports.stripe_webhook = require('./src/stripe/stripeWebhook').stripe_webhook;
exports.stripe_listInvoices = require('./src/stripe/listInvoices').stripe_listInvoices;
exports.stripe_prepareSeatChangePayment = require('./src/stripe/prepareSeatChangePayment').stripe_prepareSeatChangePayment;
exports.stripe_listPaymentMethods = require('./src/stripe/listPaymentMethods').stripe_listPaymentMethods;
exports.stripe_setDefaultPaymentMethod = require('./src/stripe/setDefaultPaymentMethod').stripe_setDefaultPaymentMethod;
exports.stripe_detachPaymentMethod = require('./src/stripe/detachPaymentMethod').stripe_detachPaymentMethod;
exports.stripe_createSetupIntent = require('./src/stripe/createSetupIntent').stripe_createSetupIntent;
exports.stripe_getIncompletePayment = require('./src/stripe/getIncompletePayment').stripe_getIncompletePayment;

// --- EMPLEADOS ---
exports.createEmployeeAccount = require('./src/employees/createEmployeeAccount').createEmployeeAccount;
exports.onEmployeeStatusChanged = require('./src/employees/onEmployeeStatusChanged').handleEmployeeDeletion;

// --- NOTIFICACIONES ---
exports.sendLoginNotification = require('./src/notifications/sendLoginNotification').sendLoginNotification;
exports.sendEmployeeWelcome = require('./src/notifications/sendEmployeeWelcome').sendEmployeeWelcome;

// --- REPORTES (PDF) ---
exports.reportsScheduleMonthly = require('./src/reports/monthlyReports').reportsScheduleMonthly;
exports.reportsGenerateRange = require('./src/reports/monthlyReports').reportsGenerateRange;
