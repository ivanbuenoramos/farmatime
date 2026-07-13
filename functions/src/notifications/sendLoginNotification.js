// functions/src/notifications/sendLoginNotification.js
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { db } = require('../config/firebase');

exports.sendLoginNotification = onCall(
    { region: 'europe-west1' }, // 👈 región explícita
    async (request) => {
      const { email, name } = request.data || {};

      if (!email) throw new HttpsError('invalid-argument', 'Email requerido');

      const now = new Date().toLocaleString('es-ES', { timeZone: 'Europe/Madrid' });

      await db.collection('mail').add({
        to: [email],
        from: 'no-reply@farmatime.net',
        message: {
          subject: 'Nuevo inicio de sesión en FarmaTime',
          html: `
            <p>Hola${name ? ' ' + name : ''},</p>
            <p>Se ha detectado un nuevo inicio de sesión en tu cuenta de <b>FarmaTime</b>.</p>
            <p><b>Fecha y hora:</b> ${now}</p>
            <p>Si no has sido tú, cambia tu contraseña de inmediato o contacta con tu admin.</p>
            <br/>
            <p>— Equipo FarmaTime</p>
          `,
          text: `Se ha detectado un nuevo inicio de sesión en tu cuenta de FarmaTime el ${now}.`,
        },
      });

      return { ok: true };
    },
);
