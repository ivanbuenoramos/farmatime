// functions/src/notifications/sendLoginNotification.js
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { db } = require('../config/firebase');

exports.sendLoginNotification = onCall(
    { region: 'europe-west1' }, // 👈 región explícita
    async (request) => {
      // Sin auth cualquiera podía usar esta función para enviar correos a
      // direcciones arbitrarias (spam / phishing con nuestro remitente).
      if (!request.auth) throw new HttpsError('unauthenticated', 'Login requerido');
      const { email, name } = request.data || {};

      if (!email) throw new HttpsError('invalid-argument', 'Email requerido');
      const tokenEmail = String(request.auth.token?.email || '').toLowerCase();
      if (tokenEmail && tokenEmail !== String(email).trim().toLowerCase()) {
        throw new HttpsError('permission-denied', 'Email no coincide con la sesión');
      }

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
