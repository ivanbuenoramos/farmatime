const { setGlobalOptions } = require('firebase-functions/v2');

setGlobalOptions({
  region: 'europe-west1',
  secrets: [
    'APPLE_IAP_KEY_ID',
    'APPLE_IAP_ISSUER_ID',
    'APPLE_IAP_PRIVATE_KEY',
    // Fallback de verificación (verifyReceipt). Debe existir antes de desplegar:
    //   firebase functions:secrets:set APPLE_SHARED_SECRET
    'APPLE_SHARED_SECRET',
    'GOOGLE_PLAY_SERVICE_ACCOUNT',
  ],
});

// --- IAP ---
exports.iap_verifyPurchase = require('./src/iap/verifyPurchase').iap_verifyPurchase;
exports.iap_appStoreNotifications = require('./src/iap/appStoreNotifications').iap_appStoreNotifications;
exports.iap_googlePlayNotifications = require('./src/iap/googlePlayNotifications').iap_googlePlayNotifications;
exports.iap_cleanupLegacyBilling = require('./src/iap/cleanupLegacyBilling').iap_cleanupLegacyBilling;
exports.iap_billingGraceCron = require('./src/iap/billingGraceCron').iap_billingGraceCron;

// --- EMPLEADOS ---
exports.createEmployeeAccount = require('./src/employees/createEmployeeAccount').createEmployeeAccount;
exports.checkEmployeeEmailAvailability = require('./src/employees/checkEmployeeEmailAvailability').checkEmployeeEmailAvailability;
exports.onEmployeeStatusChanged = require('./src/employees/onEmployeeStatusChanged').handleEmployeeDeletion;
exports.deleteCompanyAccount = require('./src/employees/deleteCompanyAccount').deleteCompanyAccount;

// --- NOTIFICACIONES (EMAIL) ---
exports.sendLoginNotification = require('./src/notifications/sendLoginNotification').sendLoginNotification;
// sendEmployeeWelcome (trigger onDocumentCreated) DESACTIVADO: el email se
// envía ahora directamente desde createEmployeeAccount para no tener que
// persistir `tempPassword` en el doc principal de empleados (GDPR — el doc es
// legible por todos los compañeros). El archivo se mantiene para histórico.

// --- NOTIFICACIONES PUSH (FCM) ---
exports.onChatMessage = require('./src/notifications/onChatMessage').onChatMessage;
exports.onTimeOffWrite = require('./src/notifications/onTimeOffWrite').onTimeOffWrite;
exports.onScheduleWrite = require('./src/notifications/onScheduleWrite').onScheduleWrite;
exports.onClockRecordEdited = require('./src/notifications/onClockRecordEdited').onClockRecordEdited;
exports.onRecurringRuleWrite = require('./src/notifications/onRecurringRuleWrite').onRecurringRuleWrite;
exports.onEmployeeStatusNotify = require('./src/notifications/onEmployeeStatusNotify').onEmployeeStatusNotify;
exports.onBillingStatusChange = require('./src/notifications/onBillingStatusChange').onBillingStatusChange;
exports.onSeatsNearLimit = require('./src/notifications/onSeatsNearLimit').onSeatsNearLimit;

// --- NOTIFICACIONES PUSH (CRON / programadas) ---
exports.cronShiftStartReminder = require('./src/notifications/cronShiftReminder').cronShiftStartReminder;
exports.cronTomorrowShift = require('./src/notifications/cronShiftReminder').cronTomorrowShift;
exports.cronClockAlerts = require('./src/notifications/cronClockAlerts').cronClockAlerts;
exports.cronBillingReminders = require('./src/notifications/cronBillingReminders').cronBillingReminders;
exports.cronPendingLeaves = require('./src/notifications/cronPendingLeaves').cronPendingLeaves;

// --- REPORTES (PDF) ---
exports.reportsScheduleMonthly = require('./src/reports/monthlyReports').reportsScheduleMonthly;
exports.reportsGenerateRange = require('./src/reports/monthlyReports').reportsGenerateRange;
exports.reportsOnClockRecordWrite = require('./src/reports/monthlyReports').reportsOnClockRecordWrite;
