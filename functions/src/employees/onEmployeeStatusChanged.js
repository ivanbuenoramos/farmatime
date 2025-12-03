const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { admin } = require('../config/firebase'); // Asegúrate de tener initializedApp aquí
const logger = require('firebase-functions/logger');

exports.handleEmployeeDeletion = onDocumentUpdated(
    'employees/{employeeId}',
    async (event) => {
      const beforeData = event.data.before.data();
      const afterData = event.data.after.data();

      // Si no había documento antes, o datos inesperados
      if (!beforeData || !afterData) return;

      const beforeStatus = beforeData.accountStatus;
      const afterStatus = afterData.accountStatus;

      // Solo actuamos si pasó de algo → 'deleted'
      if (beforeStatus === afterStatus) return;
      if (afterStatus !== 'deleted') return;

      const uid = afterData.authUid || afterData.uid || null;
      const email = afterData.email || null;

      if (!uid && !email) {
        logger.error(
            'No UID ni email disponible para eliminar la cuenta Auth',
            afterData,
        );
        return;
      }

      try {
        if (uid) {
          // Eliminar por UID directamente
          await admin.auth().deleteUser(uid);
          logger.info(`Cuenta Auth eliminada por UID: ${uid}`);
        } else if (email) {
          // Buscar usuario por email si no hay UID
          const user = await admin.auth().getUserByEmail(email);
          await admin.auth().deleteUser(user.uid);
          logger.info(`Cuenta Auth eliminada por email: ${email}`);
        }
      } catch (err) {
        logger.error('Error eliminando usuario de FirebaseAuth:', err);
      }
    },
);
