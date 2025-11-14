const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { logger } = require('firebase-functions');
const { db } = require('../config/firebase');

exports.sendEmployeeWelcome = onDocumentCreated('employees/{employeeId}', async (event) => {
  const snap = event.data;
  if (!snap) {
    logger.warn('⚠️ Evento vacío.');
    return;
  }

  const data = snap.data();
  if (!data || !data.email || !data.tempPassword) {
    // logger.warn('⚠️ Falta email o tempPassword en el empleado. No se enviará correo.');
    // return null;
  }

  const { email, name, tempPassword } = data;
  logger.info(`📩 Nuevo empleado detectado: ${email} (${name || 'Sin nombre'})`);

  const now = new Date().toLocaleString('es-ES', { timeZone: 'Europe/Madrid' });

  const subject = `Bienvenido a FarmaTime`;
  const html = `
    <p>Hola${name ? ' ' + name : ''},</p>
    <p>Tu cuenta de empleado en <b>FarmaTime</b> ha sido creada correctamente.</p>
    <p>Estos son tus datos de acceso:</p>
    <ul>
      <li><b>Email:</b> ${email}</li>
      <li><b>Contraseña temporal:</b> ${tempPassword}</li>
    </ul>
    <p>Por seguridad, cambia la contraseña al iniciar sesión.</p>
    <br/>
    <p>Fecha de creación: ${now}</p>
    <p>— Equipo FarmaTime</p>
  `;
  const text = `
    Hola${name ? ' ' + name : ''},
    Tu cuenta de empleado en FarmaTime ha sido creada.
    Email: ${email}
    Contraseña temporal: ${tempPassword}
    Por seguridad, cambia la contraseña al iniciar sesión.
    Fecha: ${now}
  `;

  await db.collection('mail').add({
    to: [email],
    from: 'no-reply@farmatime.net',
    message: { subject, html, text },
  });

  logger.info(`✅ Correo de bienvenida enviado a ${email}`);
  return null;
});
