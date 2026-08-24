# Anexo de privacidad específico de la app (borrador para publicar en farmatime.net)

## Por qué hace falta

La política actual en https://farmatime.net/politica-de-privacidad/ está fechada
en **noviembre de 2023**, va a nombre de *Marketing and Shop Online S.L. /
Farmajobs* y describe únicamente el tratamiento de datos de **la web**: su
apartado 4 solo menciona «datos de carácter identificativo» y cookies.

No cubre nada de lo que la app hace hoy: geolocalización en el fichaje, registro
de jornada, salario por hora, mensajería interna, tokens de notificaciones push
ni suscripciones. Google contrasta el formulario de Seguridad de los datos con
la política de privacidad enlazada; una discrepancia de este tamaño es motivo
habitual de rechazo, y con RGPD además es un incumplimiento en sí mismo, porque
se tratan datos de empleados (ubicación y jornada laboral) sin informarlos.

Lo de abajo es un **borrador** para añadir como sección nueva a la política
existente o como página aparte enlazada desde ella. Revísalo con quien lleve
vuestra protección de datos antes de publicarlo: yo no puedo darte asesoramiento
legal, solo asegurar que lo declarado coincide con lo que el código hace.

---

## Tratamiento de datos en la aplicación Farmatime

### 1. Responsable y encargado del tratamiento

Farmatime es una herramienta de gestión de personal que utilizan farmacias para
organizar a sus trabajadores. Conviene distinguir dos papeles:

- Respecto de los datos de **la farmacia como cliente** (datos de contacto,
  facturación y suscripción), Marketing and Shop Online S.L. actúa como
  **responsable del tratamiento**.
- Respecto de los datos de **los empleados** de cada farmacia (jornada,
  ubicación de fichaje, ausencias, mensajes, retribución), la **farmacia
  empleadora es la responsable del tratamiento** y Marketing and Shop Online
  S.L. actúa como **encargada**, tratando esos datos únicamente conforme a sus
  instrucciones y a lo previsto en el artículo 28 del RGPD.

### 2. Datos que trata la aplicación

**De la farmacia:** denominación social, NIF/CIF, dirección, teléfono, correo
electrónico, logotipo y datos de estado de la suscripción.

**De cada empleado:** nombre, correo electrónico, fotografía de perfil (opcional),
puesto y categoría profesional, tipo de jornada, fecha de alta, retribución por
hora, registros de entrada y salida, turnos y horarios asignados, solicitudes de
vacaciones y días personales, y mensajes enviados a través del chat interno.

**Ubicación:** cuando un empleado ficha, la app puede registrar las coordenadas
del dispositivo **en ese instante concreto**. Es un dato **opcional**: si se
deniega el permiso o la ubicación está desactivada, el fichaje se registra
igualmente sin coordenadas. La aplicación **no realiza ningún seguimiento en
segundo plano** ni conoce la ubicación del empleado fuera del momento puntual
del fichaje.

**Identificadores técnicos:** identificador de usuario y token de notificaciones
push, necesario para entregar avisos de mensajes, turnos y ausencias.

### 3. Finalidades y bases jurídicas

| Finalidad | Base jurídica |
|---|---|
| Registro de jornada laboral | Obligación legal del empleador (art. 34.9 ET, RD-ley 8/2019) |
| Gestión de turnos, ausencias y comunicación interna | Ejecución del contrato laboral e interés legítimo del empleador |
| Constancia del lugar de fichaje | Interés legítimo del empleador en verificar el registro, siendo un dato opcional que el trabajador puede no facilitar |
| Gestión de la cuenta y de la suscripción | Ejecución del contrato con la farmacia |
| Notificaciones push operativas | Ejecución del contrato; el usuario puede desactivarlas en su dispositivo |

### 4. Conservación

Los registros de jornada se conservan **cuatro años**, según exige el RD-ley
8/2019. El resto de datos se conservan mientras la cuenta esté activa y se
eliminan cuando la farmacia da de baja al empleado o cancela su cuenta, salvo
los que deban mantenerse por obligación legal.

### 5. Destinatarios y ubicación de los datos

Los datos se alojan en **Google Firebase** (Google Cloud EMEA Limited), que
actúa como subencargado del tratamiento, con los servidores del proyecto en la
región **europe-west1 (Bélgica)**, dentro del Espacio Económico Europeo. No se
ceden datos a terceros con fines comerciales ni publicitarios. La aplicación no
incorpora herramientas de analítica ni de publicidad.

Las suscripciones se tramitan a través de **Google Play** y **App Store**;
Farmatime no accede en ningún momento a los datos de la tarjeta de pago.

### 6. Derechos

Cualquier persona puede ejercer sus derechos de acceso, rectificación,
supresión, oposición, limitación y portabilidad escribiendo a
**info@farmatime.net**. Los empleados pueden dirigirse tanto a su farmacia
empleadora, en su condición de responsable, como a nosotros, que trasladaremos
la solicitud.

Para eliminar la cuenta hay instrucciones en
https://farmatime.net/eliminar-cuenta/ y también puede hacerse directamente
desde la propia aplicación, en Configuración → Eliminar cuenta.
