const { setGlobalOptions } = require('firebase-functions/v2');
setGlobalOptions({
  region: 'europe-west1',
  secrets: ['STRIPE_SECRET_KEY', 'STRIPE_WEBHOOK_SECRET'],
});

// --- STRIPE ---
exports.stripe_createCustomer = require('./src/stripe/createCustomer').stripe_createCustomer;
exports.stripe_createSeatCheckoutSession = require('./src/stripe/createSeatCheckoutSession').stripe_createSeatCheckoutSession;
exports.stripe_createBillingPortalSession = require('./src/stripe/createBillingPortalSession').stripe_createBillingPortalSession;
exports.stripe_previewSeatChange = require('./src/stripe/previewSeatChange').stripe_previewSeatChange;
exports.stripe_listInvoices = require('./src/stripe/listInvoices').stripe_listInvoices;
exports.stripe_webhook = require('./src/stripe/stripeWebhook').stripe_webhook;

// --- EMPLEADOS ---
exports.createEmployeeAccount = require('./src/employees/createEmployeeAccount').createEmployeeAccount;
exports.onEmployeeStatusChanged = require('./src/employees/onEmployeeStatusChanged').handleEmployeeDeletion;

// --- NOTIFICACIONES ---
exports.sendLoginNotification = require('./src/notifications/sendLoginNotification').sendLoginNotification;
exports.sendEmployeeWelcome = require('./src/notifications/sendEmployeeWelcome').sendEmployeeWelcome;

// --- REPORTES (PDF) ---
exports.reportsScheduleMonthly = require('./src/reports/monthlyReports').reportsScheduleMonthly;
exports.reportsGenerateRange = require('./src/reports/monthlyReports').reportsGenerateRange;
