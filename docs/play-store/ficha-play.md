# Ficha de Google Play — textos y material

## Datos básicos

- **Nombre de la app:** Farmatime
- **Package:** `net.farmatime.app`
- **Categoría:** Empresa (alternativa: Productividad). **No usar Medicina**: la
  app gestiona jornada laboral, no datos de salud, y esa categoría activa
  políticas adicionales innecesarias.
- **Etiquetas sugeridas:** control horario, gestión de turnos, recursos humanos
- **Correo de contacto:** info@farmatime.net
- **Teléfono:** (+34) 644 823 846
- **Sitio web:** https://farmatime.net/
- **Política de privacidad:** https://farmatime.net/politica-de-privacidad/
  (pendiente de ampliar, ver `privacidad-app-anexo.md`)

## Descripción breve (máx. 80 caracteres)

```
Control horario, turnos y ausencias para el equipo de tu farmacia.
```

## Descripción completa (máx. 4000 caracteres)

```
Farmatime es la aplicación de control horario y gestión de personal pensada
específicamente para farmacias.

Cumple con el registro de jornada obligatorio, organiza los turnos de tu equipo
y centraliza la comunicación diaria, todo desde el móvil y sin papeleo.

FICHAJE SENCILLO
Tus empleados fichan la entrada y la salida con un toque. Cada registro queda
guardado con su hora exacta y, opcionalmente, con la ubicación del momento del
fichaje. Si alguien olvida fichar, el panel de la farmacia lo detecta y avisa.

REGISTRO DE JORNADA CONFORME A LA NORMATIVA
Farmatime conserva el histórico de jornada que exige el Real Decreto-ley 8/2019
y te permite descargar informes en PDF cuando los necesites. Cualquier
modificación de un fichaje queda registrada en un historial de auditoría
inalterable, con quién la hizo, cuándo y por qué.

TURNOS Y HORARIOS
Crea plantillas de turno y aplícalas a tu equipo, define horarios recurrentes
por empleado y ajusta días sueltos cuando haga falta. Cada trabajador ve su
calendario actualizado al instante.

VACACIONES Y AUSENCIAS
Los empleados solicitan vacaciones o días personales desde la app. La farmacia
puede aprobarlas, rechazarlas o proponer fechas alternativas, y todo el mundo
recibe un aviso al momento. Se acabaron los mensajes sueltos y las notas en el
mostrador.

CHAT INTEGRADO
Conversaciones individuales entre compañeros y con la farmacia, más un grupo
automático con todo el equipo. Las notificaciones push mantienen a todos al día
sin salir de la aplicación.

PANEL PARA LA FARMACIA
Consulta de un vistazo quién está trabajando, quién ha fichado y qué incidencias
hay pendientes. Gestiona altas y bajas de empleados en segundos.

PLANES
Farmatime funciona por suscripción mensual según el tamaño de tu equipo:

• Hasta 5 empleados — 3,99 €/mes
• Hasta 10 empleados — 8,99 €/mes
• Hasta 20 empleados — 17,99 €/mes

El número de plazas incluye la cuenta de la propia farmacia. El pago se realiza
a través de Google Play y la suscripción se renueva automáticamente cada mes,
salvo que se cancele al menos 24 horas antes de la fecha de renovación. Puedes
gestionar o cancelar tu suscripción en cualquier momento desde los ajustes de tu
cuenta de Google Play.

Términos de uso: https://farmatime.net/terminos-de-uso/
Política de privacidad: https://farmatime.net/politica-de-privacidad/
```

## Acceso para revisores (App access)

**Imprescindible.** La app es de acceso restringido: sin credenciales, el
revisor solo ve la pantalla de login y el rechazo es automático. Hay que
preparar y declarar en Play Console → Política → Acceso a la app:

1. **Cuenta de farmacia (admin)** con suscripción activa, para que el revisor
   pueda ver el panel completo, la gestión de empleados y la pantalla de
   suscripción. Sin plan activo no verá la mitad de la app.
2. **Cuenta de empleado** asociada a esa misma farmacia, para el flujo de
   fichaje, calendario y solicitudes de ausencia.

Instrucciones a pegar en el campo de notas:

```
La aplicación distingue dos tipos de cuenta. Se facilitan credenciales de ambas.

CUENTA DE FARMACIA (administrador)
Usuario: <email>
Contraseña: <password>
Permite acceder al panel de control, la gestión de empleados, los informes de
jornada y la pantalla de suscripción.

CUENTA DE EMPLEADO
Usuario: <email>
Contraseña: <password>
Permite fichar entrada y salida, consultar el calendario de turnos y solicitar
vacaciones.

La app está disponible únicamente en español y dirigida a farmacias españolas.
El permiso de ubicación es opcional: si se deniega, el fichaje se registra
igualmente sin coordenadas.
```

## Material gráfico pendiente

| Recurso | Requisito de Play | Estado |
|---|---|---|
| Icono | 512×512 PNG, 32 bits | Existe en la app (`launcher_icon`), hay que exportarlo al tamaño exacto |
| Gráfico destacado | 1024×500 PNG o JPG | **Falta** |
| Capturas de teléfono | Mín. 2, máx. 8; entre 320 px y 3840 px de lado | **Faltan** |
| Capturas de tablet 7" y 10" | Solo si declaras compatibilidad con tablets | **Faltan** |
| Vídeo promocional | Opcional (URL de YouTube) | No necesario |

Capturas recomendadas, en este orden: pantalla de fichaje del empleado, panel de
la farmacia, calendario de turnos, solicitud de ausencias, chat y pantalla de
planes.
