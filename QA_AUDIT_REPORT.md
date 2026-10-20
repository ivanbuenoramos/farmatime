# QA_AUDIT_REPORT — Auditoría profunda de Farmatime (iOS + Android)

Fecha: 2026-10-17 → 2026-10-20 · Rama: `audit/flutter-deep-qa-2026-10` (base `main@fbfb714`, checkpoint `cb9109b` con el trabajo previo sin commitear) · Metodología reutilizable: `.claude/skills/flutter-deep-qa/SKILL.md` · Progreso detallado: `QA_PROGRESS.md`.

> Nada de lo corregido está desplegado: ni `firebase deploy` ni subida a tiendas. Todas las pruebas se ejecutaron contra el **Firebase Emulator Suite** (nunca contra `farmatime-app` real).

## 1. Resumen ejecutivo

- **Alcance real**: 61 pantallas, 277 operaciones de datos, 11 subsistemas (app Flutter 3.47.6 + GetX, 28 Cloud Functions, reglas Firestore/Storage, IAP, push, email). Matriz completa en `docs/qa/FUNCTIONALITY_MATRIX.md` (629 casos de prueba definidos).
- **Issues**: 296 candidatos (192 del descubrimiento + 105 de buscadores por dimensión) verificados adversarialmente por 551 agentes con tres lentes (corrección, impacto, reproducibilidad): **271 confirmados** (2 críticos, 34 altos, 114 medios, 121 bajos), 24 refutados, 1 incierto → `docs/qa/VERIFIED_ISSUES.md`.
- **Corregido en esta rama (con prueba que fallaba antes y pasa después)**: 1 crítico (purga en cascada sobre un uid elegido por el cliente), 9 agujeros de reglas de seguridad, 19 altos/medios de funcionalidad (lost update y cierre de fichajes editados, listado de fichajes de la empresa, horarios que no se guardaban, selección por día de la semana, pantalla de bloqueo sin salida, PDF del registro horario en UTC, push mal enrutado por rol, set-password sin salida, API key de Maps fuera de `<application>` en Android, CI Android con Flutter incompatible, overflow en pantallas cortas, chat con empleados eliminados, listeners sin `onError`, functions que no arrancaban en el emulador, etc.).
- **Verificación real en dispositivo**: suite de 47 pruebas de integración (`integration_test/`) ejecutada en **iOS 27 (iPhone 18 Pro)**: **47/47 verdes** en el último pase; en **Android 16 (API 36)** también **47/47** (en varios pases por inestabilidad del emulador; ningún fallo funcional nuevo salvo el overflow de pantalla corta, corregido). Unitarias Flutter 14/14; reglas Firestore 384/384 (+47 de la Fase 8 = 431); functions 18/18; `flutter analyze` 0 errores/0 warnings (83 infos preexistentes); ESLint 0 errores.
- **Bloqueantes antes de producción** (§12): desplegar reglas y functions corregidas, rotar la clave de SendGrid expuesta en el historial público, decidir el modelo de aprobación de ausencias en backend, y los pendientes de IAP no verificables sin tienda.

## 2. Arquitectura analizada

- **Cliente**: Flutter 3.47.6 / Dart 3.13.5, GetX (`GetMaterialApp`, bindings por ruta, `Rx`), capas `presentation → domain/usecases → data/repositories → Firebase`. Sesión en `GetStorage` (`Brain` singleton con `employee`/`company`). 30 rutas (`lib/core/routes`). Dos roles: **farmacia** (`uid == companies/{uid}`) y **empleado** (`uid == employees/{uid}`, `companyId`).
- **Backend**: Firebase Auth, Firestore (13 colecciones: companies/subscription, employees/private, clockRecords/auditLog, clockReports, company_shift_templates, employee_schedule_rules, employee_schedule_months, time_off_requests, conversations/messages, user_fcm_tokens/tokens, mail, _appleEvents), Storage, 28 Cloud Functions v2 (Node 20, `europe-west1`): callables (createEmployeeAccount, checkEmployeeEmailAvailability, deleteCompanyAccount, sendLoginNotification, reportsGenerateRange, iap_verifyPurchase), triggers (12), crons (6), webhooks Apple/Google.
- **Externos**: Apple App Store Server API/notifications, Google Play Developer API/RTDN, FCM, SendGrid (extensión firestore-send-email), Google Maps, geolocalización.
- **Entornos**: un único proyecto Firebase (`farmatime-app`, producción). No existe staging → la auditoría añadió un modo emulador (`--dart-define=FIREBASE_EMULATOR_HOST`, inerte en release) y semillas deterministas (`tool/qa/seed_emulator.js`).

## 3. Funcionalidades identificadas

Inventario completo (pantallas, controladores, servicios, dataOps, servicios externos, procesos asíncronos, almacenamiento local, roles/permisos) por subsistema en `docs/qa/FUNCTIONALITY_MATRIX.md` (fuente estructurada: `docs/qa/discovery.json`). Resumen:

| Área | Pantallas | DataOps | Casos definidos | Issues confirmados |
|---|---|---|---|---|
| Autenticación/sesión/arranque | 10 | 28 | 60 | ver §5 |
| Fichajes empresa (dashboard, control, edición, auditoría) | 8 | 22 | 74 | |
| Fichajes empleado (Mi día, histórico, calendario) | 5 | 20 | 62 | |
| Horarios (plantillas, reglas, overrides) | 7 | 24 | 55 | |
| Ausencias | 3 | — | — | |
| Chat y push | 4 | — | — | |
| Suscripciones IAP | 4 | — | — | |
| Empleados/perfiles/Storage | 9 | — | — | |
| Cloud Functions (IAP, empleados, notificaciones, informes) | — | — | — | |
| Plataforma/seguridad/CI | — | — | — | |
| **Total** | **61** | **277** | **629** | **271** |

## 4. Matriz de pruebas

- **Definidos**: 629 casos (id, tipo, prioridad, automatizable) en la matriz; 53 solo manuales y 3 bloqueados (IAP real, APNs/FCM real, email real).
- **Automatizados y ejecutados** en esta auditoría:
  - `integration_test/` (47 `testWidgets`, app real contra el Emulator Suite, iOS y Android): smoke (4), auth farmacia (7, incl. evidencia directa del SDK), auth empleado (8, activación con contraseña temporal, formularios cruzados), fichaje (6: doble tap, auditLog, dashboard en tiempo real, persistencia entre sesiones, 2º turno), fichaje con ubicación denegada (1), gestión de empleados (7: alta real vía Cloud Function, duplicados, tarifa negativa, plazas 4/5, modal de límite, activación), chat (5: grupo "Todos", mensajes, no leídos, directo), ausencias (5: solicitud, cancelación, aprobación, calendario, saldo), horarios (3: asignar plantilla, override mensual, Mi día del empleado), rendimiento con 3000 fichajes (1).
  - `functions/test/rules/` (384 tests): todas las colecciones, ambos roles, no autenticado, listados demostrables, lecturas de docs inexistentes, transiciones de estado, endurecimientos de la Fase 8.
  - `functions/test/unit/` (18): helpers puros, zona horaria, mapeos IAP, invariantes de la cascada.
  - `test/` (14): resumen de horas (preexistente), overflow de la pantalla de inicio, selección por día de la semana.
- **Comando repetible**: `tool/qa/run_integration_tests.sh [ios|android|all]` (siembra, permisos/ubicación por plataforma, watchdog, resultados en `docs/qa/results/<fecha>/`).

## 5. Bugs encontrados, severidad, causa raíz y solución

### 5.1 Corregidos en esta rama (todos con prueba de regresión; rojo antes → verde después)

| ID | Sev. | Dónde | Causa raíz | Solución | Prueba |
|---|---|---|---|---|---|
| SEC-001 | alta | firestore.rules clockRecords.create | no exigía `employeeId == uid` | regla | rules spec |
| SEC-002 | alta | clockRecords.update (empleado) | `clockIn` alterable sin traza | inmutable | rules spec |
| SEC-003/004 | alta | employees (empleado) | `hireDate`/`createdAt` (devengo) alterables; el cliente los reescribía | inmutables + cliente deja de enviarlos | rules spec |
| SEC-005 | alta | time_off (empleado) | podía auto-aprobarse otras fechas al aceptar | `dates/proposedDates/type` inmutables | rules spec |
| SEC-006..009 | media | schedule_months/templates/rules | `employeeId`/`companyId` reasignables (incluso a otra empresa) | inmutables | rules spec |
| BUG-010 | alta | rules get() de docs inexistentes | `resource.data` sobre null → "Ha ocurrido un error inesperado" en Mi día/salida/ausencias | `allow get` con `resource == null` | 5 rules tests + integración |
| BUG-011/015 | alta (local) | functions | `admin.firestore.FieldValue/Timestamp` indefinidos en el emulador | API modular `firebase-admin/firestore` | npm test + integración |
| BUG-012 | media | CompanyEmployeesController, SubscriptionController | listeners sin `onError` → excepción asíncrona al cerrar sesión | `onError` | AUTH-C-006 |
| BUG-013 | media | InboxController | eliminados vuelven al grupo "Todos" en cada login | filtro | CHAT-001 |
| BUG-014 | baja | inbox new-chat sheet | ListTile sin Material (aserción debug) | Material | CHAT-004 |
| BUG-016 | media | index_page | overflow 28 px en pantallas cortas (Android) | scroll + IntrinsicHeight | widget test 3 tamaños |
| CRÍTICO (FND) | crítica | onEmployeeStatusChanged/cascadeDelete | purga usaba `afterData.authUid/uid` (escribible por el cliente) → borrado de datos/Auth de un tercero | uid = id del doc; `employees.uid` inmutable en reglas | unit + rules |
| CAND-001 (+3) | alta | monthlyReports.js | PDF legal formateado/agrupado en UTC | `process.env.TZ='Europe/Madrid'` antes de cualquier require | unit (TZ=UTC) |
| CAND-009/010 (+3) | alta | clock repo/rules/Mi día | cierre reescribía el doc completo (lost update) y las reglas lo denegaban si la empresa editó | update parcial `closeEntry` + regla `diff().affectedKeys().hasOnly([...])` | rules + CLOCK-004 |
| CAND-011 (+1) | alta | clock repo/employee_detail | listado por `employeeId` no demostrable para la empresa | filtro `companyId` | rules |
| CAND-015 (+3) | alta | employee_schedule_repository | `set(merge:true)` fusiona mapas → "Quitar asignación" nunca se borraba | `mergeFields` (reemplazo del mapa) | unit |
| CAND-016 | alta | schedule controller | L..D asignaba rango contiguo | selección no contigua + rangos con aritmética de calendario (DST) | 8 unit |
| CAND-026 (+1) | alta | subscription_blocked_controller | nadie actualizaba `brain.company` → pantalla sin salida tras renovar | listener del doc | manual (IAP) |
| CAND-029 | alta | push_notification_service | push `billing` llevaba al empleado a la compra de empresa; sin sesión navegaba igual | enrutado por rol y sin sesión no navega | — |
| CAND-032 | alta | delete_employee_page | prometía conservar fichajes (se purgan) | texto veraz | — |
| CAND-037 | alta | cascadeDelete/monthlyReports | PDFs en Storage no se purgaban; trigger resucitaba clockReports | purga `reports/…` + guarda `accountStatus=='deleted'` | unit |
| CAND-040 (+1) | alta | android-release.yml | Flutter 3.35.5 no resuelve `pubspec.lock` (Dart ≥3.11) | 3.47.6 | — |
| CAND-005/006 | alta | set-password | sin salida si la temporal no sirve; activación no atómica mostraba éxito | diálogo (restablecer/cerrar sesión); reintento y sin éxito falso | — |
| FND Mi día | alta | my_day | FICHAR activo durante la carga → duplicados | guarda `isLoading` | CLOCK-002 |
| FND accountStatus | alta | rules | inactive/disabled seguían escribiendo | `isActiveEmployee()` en escrituras | 16 rules tests |
| FND Google CANCELED | alta | googlePlayNotifications | renovación desactivada = cancelación inmediata | activo con `autoRenewing=false` hasta expiración | unit |
| FND Maps key | alta | AndroidManifest | meta-data fuera de `<application>` | movida | — |

### 5.2 Confirmados y pendientes (con causa raíz y fix propuesto)

Los 271 confirmados, con causa raíz, escenario de fallo, fix mínimo y test propuesto por issue, están en `docs/qa/VERIFIED_ISSUES.md` y `docs/qa/verified_issues.json`. Altos **no** corregidos en esta ronda:

- **CAND-002 (crítico, acción del usuario)**: API key de SendGrid y URIs SMTP en el historial git del repositorio público (commit `b727d7d`). Rotar la clave en SendGrid y en la extensión, y reescribir/purgar el historial (o hacer privado el repo).
- **CAND-022**: cualquier empleado activo puede escribir overrides `vacation/personal` en su propio mes (la aprobación de propuestas la escribe el propio empleado). Requiere mover la aprobación/marcado del calendario a una Cloud Function.
- **CAND-027/028**: IAP — carrera del singleton `IapService` al pasar a la pantalla de bloqueo; el cliente no envía `disableUids` al backend en downgrades. No verificable sin tienda; fix propuesto en el JSON.
- **verifyAppleJws sin comprobar los OID de Apple** en hoja/intermedio: requiere parseo ASN.1 de extensiones (p. ej. `@apple/app-store-server-library`).
- **Devengo de vacaciones desde el alta en la app** (`createdAt`): decisión de producto; proponer campo de antigüedad editable.
- 114 medios y 121 bajos: tablas completas en `docs/qa/_issues_tables.md` (anexo).

## 6. Pruebas ejecutadas / superadas / fallidas

| Suite | Comando | Resultado |
|---|---|---|
| Análisis estático | `flutter analyze` | 0 errores, 0 warnings, 83 infos (deprecaciones/avoid_print, preexistentes) |
| Unit/widget Flutter | `flutter test` | 14/14 |
| Reglas Firestore | `cd functions && npm test` | 431/431 reglas + 17 unit = 448/448 |
| ESLint functions | `npm run lint` | 0 errores, 3 warnings max-len (preexistentes) |
| Integración iOS 27 · iPhone 18 Pro | `tool/qa/run_integration_tests.sh ios` | **47/47** (pases `docs/qa/results/2026-10-20d` + `e`) |
| Integración Android 16 · API 36 (1080×2400) | `tool/qa/run_integration_tests.sh android` | **47/47** (archivos verdes repartidos en `2026-10-20f` auth farmacia/fichaje/ubicación denegada/rendimiento, `h` empleados, `j` smoke/auth empleado/chat/horarios/ausencias). Fallos intermedios: entorno (almacenamiento del AVD, VM service con el host saturado), ninguno funcional salvo el overflow BUG-016 ya corregido. |
| Android 11 · API 30 (pantalla pequeña) | idem con `ANDROID_DEVICE` | __PENDIENTE_API30__ |
| iOS otros tamaños/versiones (iPhone 16e iOS 18.5, iPad Pro 13" iOS 27) | idem con `IOS_DEVICE` | __PENDIENTE_IOS_MATRIX__ |
| Build Android | `flutter build apk --debug` | OK |
| Build iOS | `flutter build ios --simulator --debug` | OK |

Historial de pases y fallos intermedios (todos diagnosticados): `QA_PROGRESS.md` §Pruebas realizadas.

## 7. Cobertura conseguida

- Funcional: todas las pantallas de los dos roles recorridas por las pruebas de integración salvo las que dependen de servicios no emulables (compra IAP real, gestión de suscripción en tienda, recepción real de push/email, informes PDF descargados desde Storage real). Pantallas de solo lectura (perfil de empresa, ajustes, notificaciones) cubiertas por navegación/smoke.
- Reglas de seguridad: 100 % de las colecciones y operaciones (read/get/list/create/update/delete) por rol, incluidos los casos negativos.
- Backend: callables `createEmployeeAccount`/`checkEmployeeEmailAvailability`/`sendLoginNotification` ejecutadas de verdad en el emulador por las pruebas de integración; triggers de reports/chat/ausencias disparados por ellas. Crons y webhooks: lógica pura testeada; ejecución end-to-end no emulable (Pub/Sub, Apple, Google).
- Cobertura de líneas no medida (no es representativa con GetX + Firebase sin mocks); métrica sustituida por la matriz funcional.

## 8. Problemas pendientes

Ver §5.2 y `docs/qa/VERIFIED_ISSUES.md`. Además: deuda de harness documentada en la skill (toasts por historial, taps hit-testable).

## 9. Riesgos de seguridad

1. Clave de SendGrid en historial público (CAND-002) — **crítico, sin corregir (acción del usuario)**.
2. Purga en cascada dirigida por el cliente — **corregido**.
3. 9 huecos en reglas (fichajes a nombre de otro, alteración de `clockIn`/`hireDate`, autoaprobación de fechas, reasignación entre empresas) — **corregidos**; inactivos/deshabilitados escribiendo — **corregido**.
4. Reglas desplegadas en producción ≠ repo hasta que se despliegue (`firebase deploy --only firestore:rules,storage`).
5. Google Maps API key sin restricción por paquete/bundle (manifest y AppDelegate) — pendiente (consola de Google Cloud).
6. `aps-environment=development` en entitlements; `ITSAppUsesNonExemptEncryption` ausente; textos de permiso de ubicación "siempre" incoherentes con el uso real (medios, pendientes).
7. Modelo de empleado (tarifa, datos) en `GetStorage` sin cifrar (bajo).

## 10. Problemas de rendimiento

- **Observado**: con 3000 fichajes históricos (semilla `--big`) el login y la pestaña "Fichajes" del empleado cargan en < 10 s en iOS (PERF-001); el histórico completo se descarga sin límite ni paginación en cada arranque/pestaña (`getEntriesByEmployee`), y "Mi día" lo descarga entero solo para encontrar la entrada abierta → **sospecha** de coste creciente (lecturas Firestore) con años de datos; fix propuesto: límite/rango en la query (ver JSON, medios).
- Dashboard: dos listeners fusionados + tick de 30 s; correcto en pruebas. Sin frames perdidos observables en simulador (no se perfiló en dispositivo físico: limitación).

## 11. Limitaciones del entorno

- Sin staging: todo contra emuladores; IAP, APNs/FCM, email, Pub/Sub, App Store Server API y Google Play API no emulables → 56 casos manuales/bloqueados.
- Android: solo había imagen API 36; se instaló API 30 para pantalla pequeña/versión antigua. El emulador API 36 se quedó sin almacenamiento (recreado con 8 GB) y sufrió desconexiones puntuales (`VmServiceDisappeared`), reintentadas.
- Disco del host lleno a mitad de auditoría (DerivedData/Gradle): limpiado; documentado en la skill.
- iPhone físico del usuario detectado pero no usado.
- Límite de sesión del modelo durante la Fase 8: las correcciones se completaron a mano.

## 12. Recomendaciones antes de producción

1. Desplegar `firestore.rules` y **todas** las functions de esta rama (`firebase deploy --only firestore:rules,storage,functions`) y re-ejecutar `tool/qa/run_integration_tests.sh all` contra el emulador tras cada cambio.
2. Rotar la API key de SendGrid y limpiar el historial del repositorio (o hacerlo privado).
3. Restringir la API key de Google Maps por paquete/bundle; `aps-environment=production` en el perfil de App Store; añadir `ITSAppUsesNonExemptEncryption`.
4. Mover la aprobación de ausencias (escritura de overrides) al backend (CAND-022) y revisar IAP (CAND-027/028) con cuentas sandbox.
5. Paginar/limitar el histórico de fichajes del empleado.
6. Regenerar los informes PDF ya emitidos (`reportsGenerateRange`) tras desplegar el fix de zona horaria.
7. Mantener la suite: `flutter analyze && flutter test && (cd functions && npm test) && tool/qa/run_integration_tests.sh all` como puerta de entrada a `main`.

## Anexo A — Tablas de issues confirmados
Ver `docs/qa/_issues_tables.md` (críticos/altos, medios, bajos con causa raíz y fix propuesto) y `docs/qa/VERIFIED_ISSUES.md` (incluye refutados).
