# QA_PROGRESS — Auditoría profunda Farmatime (iOS + Android)

> Actualizado continuamente. Rama: `audit/flutter-deep-qa-2026-10` (checkpoint `cb9109b` protege el trabajo previo; `main` intacto en `fbfb714`).
> Metodología: `.claude/skills/flutter-deep-qa/SKILL.md`. Informe final: `QA_AUDIT_REPORT.md`.

## Fase actual
**Fase 1 — Descubrimiento** (8/11 áreas leídas; 3 áreas + síntesis se reanudaron el 2026-10-20 tras un límite de uso del modelo) · **Fase 3/4** pruebas de integración ejecutándose en iOS · **Fase 6** reglas Firestore probadas y endurecidas.

## Infraestructura de pruebas (2026-10-17)
- `firebase.json`: bloque `emulators` (auth 9099, firestore 8080, functions 5001, storage 9199, UI 4000). **Bloqueo resuelto:** firebase-tools 15 exige Java 21 → se usa el JBR de Android Studio (`/Applications/Android Studio.app/Contents/jbr`). Emuladores arrancados; crons/pubsub ignorados (sin emulador Pub/Sub) — limitación documentada.
- App: `lib/core/firebase_emulator.dart` + `main.dart` + `CallableHttpClient` → conexión al Emulator Suite SOLO con `--dart-define=FIREBASE_EMULATOR_HOST` y nunca en release. `android/app/src/debug/AndroidManifest.xml` permite cleartext solo en debug. `functions/.secret.local` con secretos ficticios (ignorado).
- Semilla determinista: `tool/qa/seed_emulator.js` (2 farmacias, 5 empleados en distintos estados, 3 plantillas). Ejecutada OK contra el emulador.
- `integration_test/`: harness (`helpers/qa_harness.dart`), `smoke_test.dart`, `auth_company_test.dart`, `auth_employee_test.dart`. Runner repetible `tool/qa/run_integration_tests.sh` → `docs/qa/results/<fecha>/`.
- Reglas Firestore: `@firebase/rules-unit-testing` + mocha instalados; suite en elaboración (agente) en `functions/test/rules/`.
- Build iOS simulador (debug, modo emulador) en curso; build Android pendiente.

## Fase 0 — Preparación (completada 2026-10-17)
- CLAUDE.md: no existe en el repo (solo README plantilla y `docs/play-store/*`). Memoria de sesiones previas leída (auditorías 2026-05, 2026-09, ronda bugs 2026-10).
- Toolchain verificado: Flutter 3.47.6 stable (Dart 3.13.5) en `~/Development/flutter` (no está en PATH de la shell), Xcode 27.0 (27A266a), CocoaPods 1.16.2, Android SDK 36 / emulador 35.5.10 / Java 17 (licencias aceptadas), Node 24.2 (functions declara 20), Firebase CLI 15.32.1 (login devops@aventra.es).
- Dispositivos disponibles:
  - iOS simuladores: runtimes 18.5 (iPhone 16/16 Pro/16e, iPads M4), 26.4 (iPhone 17e, Air, iPads), 26.5 (iPhone 17/17e/17 Pro Max/Air, iPads M5), 27.0 (iPhone 17/17e/17 Pro Max/18 Pro **booted**/18 Pro Max/Air, iPads). iPhone físico "iPhone de Ivan" (iOS 27.0.1, inalámbrico) detectado — es el dispositivo personal del usuario; no se usará sin indicación expresa.
  - Android: AVD `Medium_Phone_API_36.0` (1080×2400, 420 dpi, Play image) **arrancado como emulator-5554**; AVD `flutter_emulator` (Pixel 1080×1920, GPU off). Solo hay imagen de sistema API 36 → otras versiones de Android no comprobables sin descargar imágenes (disco: 10 GB libres; ~/.gradle 22 GB, DerivedData 14 GB).
- Entornos: un único proyecto Firebase `farmatime-app` (producción). No existe staging. Para la auditoría se usará el Firebase Emulator Suite (Auth/Firestore/Functions/Storage) con un switch `--dart-define` añadido a la app (ver Fase 3).
- Git: 60 ficheros modificados sin commitear (ronda de bugs de octubre) → protegidos en commit de checkpoint en la rama de auditoría. Sin ficheros sensibles trackeados (`service-account.json`, `params.env`, `extensions/*.env` ignorados; `functions/.env.*` versionados a propósito sin secretos).
- Baseline: `flutter analyze` 83 infos / 0 warnings / 0 errores · `flutter test` 3/3 verde (1 archivo) · eslint functions 0 errores / 4 warnings max-len · sin tests de functions ni de reglas · sin `integration_test/`.

## Funcionalidades auditadas
- Descubrimiento completado (2026-10-20): 11 áreas, **61 pantallas, 277 operaciones de datos, 629 casos de prueba, 192 issues candidatos** (2 críticos, 39 altos, 73 medios, 78 bajos) → `docs/qa/FUNCTIONALITY_MATRIX.md`, `docs/qa/discovery.json`, `docs/qa/candidate_issues.json`.
- Verificadas por ejecución real (iOS, Emulator Suite): arranque, navegación inicial, login/logout farmacia y empleado (cruzados), activación con contraseña temporal, fichaje entrada/salida (en curso), chat grupo/directo (parcial), alta de empleado (en curso), ausencias (en curso), horarios (asignación de turno por plantilla OK).
- Reglas de seguridad Firestore: 385 tests unitarios (todas las colecciones).

## Funcionalidades pendientes
- Ejecución en Android (API 36 y API 30) de toda la suite; iPad / iPhone pequeño / iOS 18.5.
- Verificación adversarial de los 192 candidatos + buscadores por dimensión (workflow Fase 2 en curso).
- Suscripciones IAP, push reales, email real: no emulables (limitación documentada).

## Bugs descubiertos
- **SEC-001..SEC-009 (reglas Firestore, severidad alta/media)** — confirmados por tests unitarios de reglas (fallaban): empleado podía crear fichajes a nombre de un compañero; alterar `clockIn` sin marcar edición; modificar `hireDate`/`createdAt` (base del devengo); auto-aprobarse otras fechas al aceptar una propuesta; reasignar `employeeId` de su mes de horario; la empresa podía reasignar plantillas/reglas/meses a otra empresa.
- Candidatos del descubrimiento (8 áreas, ~190 issues candidatos sin verificar) en el journal del workflow; pendiente síntesis y verificación adversarial (Fase 2).
- **BUG-010 (alta, reglas)** — `get()` de `employee_schedule_months/{id}` inexistente era DENEGADO (la regla evaluaba `resource.data` sobre null) → cada empleado sin horario del mes veía "Ha ocurrido un error inesperado" al abrir Mi día, al fichar salida y al abrir el calendario/solicitud de ausencia (observado en iOS, `docs/qa/results/2026-10-20b`). Mismo patrón en `employees/{uid}` para el login cruzado.
- **BUG-011 (media, backend)** — `reportsOnClockRecordWrite` lanzaba `TypeError: Cannot read properties of undefined (reading 'fromDate')` en CADA escritura de clockRecords en el emulador (`admin.firestore.Timestamp` no expuesto por el proxy del emulador con firebase-admin 13). En producción el runtime sí lo expone; corregido con la API modular para que la function sea verificable en local.
- **BUG-012 (media, cliente)** — listeners de Firestore sin `onError` en `CompanyEmployeesController` (doc empresa) y `SubscriptionController`: al cerrar sesión generaban `permission-denied` sin capturar (excepción asíncrona detectada por la suite en AUTH-C-006).
- **BUG-013 (media, chat)** — `InboxController._ensureGroupChat` volvía a añadir al grupo "Todos" a los empleados ELIMINADOS en cada login (usaba todos los nombres de `getMemberNames`). Detectado por CHAT-001.
- **BUG-014 (baja, UI)** — hoja "Nueva conversación": `ListTile` dentro de un `Container` decorado sin `Material` → aserción de Flutter en debug (3 excepciones en CHAT-004).

## Bugs corregidos
- SEC-001..SEC-009 → `firestore.rules` endurecido + `EmployeeRepositoryImpl.updateEmployee` ya no reescribe `hireDate`/`createdAt` (commit en rama de auditoría). Verificación: `cd functions && npm test` → 380 passing.
- BUG-010 → reglas `allow get` con `resource == null` (mes deducido del id `{companyId}__…`; `employees/{uid}` propio). 5 tests de reglas nuevos → 385 passing. Verificación en dispositivo: pendiente (suite iOS relanzada).
- BUG-011 → `monthlyReports.js` usa `require('firebase-admin/firestore').Timestamp`.
- BUG-012 → `onError` añadido en los 3 listeners.
- BUG-013 → filtro de eliminados en `_ensureGroupChat`.
- BUG-014 → `Material(type: transparency)` alrededor del `ListTile`.

## Pruebas realizadas
- 2026-10-17 baseline: `flutter analyze`, `flutter test`, `npm run lint` (functions). Ver arriba.
- 2026-10-17 iOS (iPhone 18 Pro, iOS 27): smoke SMOKE-001 verde contra el Emulator Suite (arranque + emulador OK). SMOKE-002..004 fallaron por el harness (flutter_test desmonta la app tras cada test; `main()` pisaba `FlutterError.onError`) → corregido; cuelgue de `tearDownAll` → watchdog en el runner.
- 2026-10-20 functions: `npm test` → 380 passing (370 reglas + 10 unitarios).
- 2026-10-20 iOS: batch smoke + auth farmacia + auth empleado en ejecución (`docs/qa/results/2026-10-20/`).

## Próximas acciones
1. Terminar matriz de funcionalidades (workflow en curso).
2. Infraestructura de pruebas: emuladores Firebase (`firebase.json`), switch de emulador en `main.dart`/`CallableHttpClient`, cleartext solo debug en Android, `functions/.secret.local`.
3. Fase 2: buscadores estáticos por dimensión + verificación adversarial de `docs/qa/candidate_issues.json`.
4. Fase 3/4: integration_test en iPhone 18 Pro (iOS 27) y emulator-5554 (API 36) contra emuladores.

## Bloqueos encontrados
- **2026-10-17 ~21:55 — Disco lleno (ENOSPC)** durante las compilaciones iOS+Android (10 GB libres al empezar; `~/.gradle` 22 GB, DerivedData 14 GB). El build Android falló (`No space left on device`) y el harness no podía escribir. Resuelto borrando solo cachés regenerables: DerivedData de otros proyectos, cachés dyld de simuladores, distribuciones Gradle distintas de 8.14.3 y cachés Gradle de versiones no usadas, `functions/build` (artefactos accidentales). Resultado: 15 GB libres. No se tocaron Archives de Xcode, snapshots de AVD ni datos de usuario. Build Android relanzado.
- firebase-tools 15 exige Java 21 (sistema: 17) → resuelto con el JBR de Android Studio (ver Infraestructura).
- iOS: el simulador iPhone 18 Pro estaba apagado al lanzar el runner → el runner ahora lo arranca solo.
