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
  // Ignoramos los docs que no son la creación "real" del empleado:
  //  - sin email/tempPassword (alta a medias)
  //  - marcados como reserva (createEmployeeAccount crea un doc temporal con
  //    _pendingReservation=true para reservar plaza antes de crear el Auth user;
  //    se borra al migrar al UID real).
  if (!data || !data.email || !data.tempPassword || data._pendingReservation) {
    logger.info('sendEmployeeWelcome: doc temporal o incompleto, no enviamos');
    return null;
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
