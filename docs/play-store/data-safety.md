# Formulario de Seguridad de los datos — Google Play

Respuestas derivadas del código, no de suposiciones. Fuentes citadas en cada
fila. Si cambia el modelo de datos, hay que revisar este documento **y** el
formulario en Play Console: Google compara lo declarado con la política de
privacidad y con el comportamiento observado de la app.

## Resumen de recogida

| Categoría Play | Tipo de dato | ¿Se recoge? | ¿Se comparte? | Oblig. | Finalidad | Dónde está en el código |
|---|---|---|---|---|---|---|
| Ubicación | Ubicación precisa | Sí | No | **Opcional** | Funciones de la app | `clockInLat/Lng`, `clockOutLat/Lng` en `clock_in_out_model.dart:11-15` |
| Información personal | Nombre | Sí | No | Obligatorio | Funciones de la app, Gestión de la cuenta | `employee_model.dart:16`, `company_model.dart:17` |
| Información personal | Dirección de correo | Sí | No | Obligatorio | Funciones de la app, Gestión de la cuenta | `employee_model.dart:15`, `company_model.dart:14` |
| Información personal | Dirección | Sí | No | Opcional | Funciones de la app | `company_model.dart:19` (solo empresa) |
| Información personal | Número de teléfono | Sí | No | Opcional | Funciones de la app | `company_model.dart:20` (solo empresa) |
| Información personal | Otros datos | Sí | No | Opcional | Funciones de la app | NIF/CIF `company_model.dart:18`; puesto y rol `employee_model.dart:28,34` |
| Información financiera | Historial de compras | Sí | No | Obligatorio | Funciones de la app | Suscripción IAP: plan, estado y fechas en `company_model.dart:26-40` |
| Información financiera | Otra información financiera | Sí | No | Opcional | Funciones de la app | **Salario/hora del empleado**, `employee_model.dart:33` |
| Mensajes | Otros mensajes en la app | Sí | No | Opcional | Funciones de la app | Chat: colección `conversations/{id}/messages` |
| Fotos y vídeos | Fotos | Sí | No | Opcional | Funciones de la app | Foto de perfil `employee_model.dart:22`, logo `company_model.dart:15` |
| Actividad en la app | Otras acciones | Sí | No | Obligatorio | Funciones de la app | Fichajes, turnos y ausencias (`clockRecords`, `employee_schedule_*`, `time_off_requests`) |
| ID de dispositivo u otros | ID de dispositivo | Sí | No | Obligatorio | Funciones de la app | Token FCM, `push_notification_service.dart:151` |

## Notas para rellenar el formulario

**"Compartir" = No en todas las filas.** Play define *compartir* como transferir
datos a un tercero distinto de un encargado del tratamiento. Firebase (Google)
actúa como encargado por cuenta de Farmatime, así que no cuenta como compartir.
No hay SDK de analítica ni publicitario en el proyecto (`pubspec.yaml` solo trae
`firebase_core`, `firebase_auth`, `firebase_storage` y `firebase_messaging`), lo
cual simplifica mucho el formulario.

**Ubicación = opcional, no obligatoria.** `_getSafePosition()` en
`employee_may_day_controller.dart:206-253` devuelve `null` y el fichaje se
registra igual si el usuario deniega el permiso o tiene la ubicación apagada.
Declararla como obligatoria sería falso y contradice el comportamiento que ve el
revisor.

**Solo ubicación en primer plano.** La app llama a `getCurrentPosition()` en el
momento del fichaje; no hay servicio en background ni rastreo continuo. El
permiso `ACCESS_BACKGROUND_LOCATION` se retiró del manifest porque no se usaba.
Esto evita el formulario de permisos sensibles con vídeo justificativo.

**El salario por hora es el dato más sensible y el que más se olvida.**
`hourlyRate` se almacena por empleado. Va en *Información financiera → Otra
información financiera*.

**Cuidado con la categoría de la app.** Aunque el cliente sea una farmacia, la
app no trata datos de salud de nadie: gestiona jornada laboral. No declares
datos de salud ni elijas la categoría *Medicina* — activa políticas adicionales
que no te aplican. Encaja en *Empresa* o *Productividad*.

## Prácticas de seguridad

- **Los datos se cifran en tránsito:** Sí (todo el tráfico va por HTTPS/TLS
  contra Firebase).
- **El usuario puede solicitar que se eliminen sus datos:** Sí. Hay borrado
  in-app (`settings_controller.dart:88`, función `deleteCompanyAccount`) y
  página pública en https://farmatime.net/eliminar-cuenta/.
- **Se ha sometido a una validación de seguridad independiente:** No.
- **Compromiso con la Política de Familias:** No aplica (app laboral, no
  dirigida a menores).

## Público objetivo y contenido

- Público objetivo: **solo mayores de 18 años** (es una herramienta laboral).
- Anuncios: **no** contiene.
- Compras en la aplicación: **sí**, suscripciones de 3,99 € a 17,99 €/mes.
- Clasificación de contenido: sin contenido sensible; el cuestionario debería
  salir PEGI 3 / apto para todos.
