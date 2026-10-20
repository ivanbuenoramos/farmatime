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
- ~~Verificación adversarial de los 192 candidatos + buscadores por dimensión~~ → **Fase 2 completada**: 6 buscadores (105 hallazgos) + 192 candidatos = 296 únicos; 551 agentes de verificación (lentes corrección / impacto / reproducibilidad). Resultado: **271 confirmados (2 críticos, 34 altos, 114 medios, 121 bajos), 24 refutados, 1 incierto** → `docs/qa/VERIFIED_ISSUES.md` (+ `verified_issues.json` con causa raíz, escenario, fix mínimo y test propuesto por issue).
- **Fase 8 (2026-10-20)**: los 4 agentes murieron por límite de sesión (dejaron 2 specs útiles); las correcciones se hicieron a mano, en commit `fix: correcciones de la Fase 8`. Corregidos con regresión: CRÍTICO purga en cascada con uid del cliente; CAND-001 PDF en UTC; CAND-009/010 (+3 dup.) lost update y cierre de fichaje editado; CAND-011 (+1) listado de fichajes de la empresa; CAND-015 (+3) 'Quitar asignación'; CAND-016 selección por weekday; CAND-026 (+1) pantalla bloqueada; CAND-029 push billing a empleados; CAND-032 texto de baja; CAND-037 PDFs/clockReports en cascada; CAND-040 (+1) CI Android; CAND-005/006 set-password; FND Mi día duplicados; FND reglas accountStatus; FND Google CANCELED; FND API key Maps en manifest. Regresión: `flutter analyze` 0 err/0 warn, `flutter test` 14/14, `npm test` 448/448, lint 0 err.
- **Pendientes (altos) con propuesta documentada en `docs/qa/VERIFIED_ISSUES.md`**: CAND-002 (clave SendGrid en el historial del repo público → rotar clave y reescribir historial; acción del usuario); CAND-022 (overrides vacation/personal escribibles por el empleado: requiere mover la aprobación al backend); CAND-027/028 (IAP: race del singleton y disableUids no enviados; no verificable sin tienda); verifyAppleJws sin comprobar OIDs de Apple (requiere parser ASN.1); devengo desde el alta en la app (decisión de producto). Medios/bajos: 235 documentados con fix propuesto, no corregidos en esta ronda.
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
- 2026-10-20 iOS (iPhone 18 Pro, iOS 27), 4 pases (`docs/qa/results/2026-10-20{,b,c,d}/`): tras corregir harness y bugs, **7/10 archivos verdes** (smoke, auth empleado, chat, fichaje, fichaje sin permiso de ubicación, rendimiento con 3000 fichajes, horarios). Re-ejecución (`2026-10-20e`): auth farmacia **PASS** (el toast de contraseña incorrecta sí se muestra: era el overlay de toastification en la 2ª instancia), ausencias **PASS** (solicitud → cancelación → aprobación por la farmacia → calendario marcado → saldo), gestión de empleados 6/7 (EMP-004 alta real vía Cloud Function OK; fallo residual del test por tarifa no rellenada, corregido). → **iOS (iPhone 18 Pro, iOS 27): 10/10 archivos verdes** (gestión de empleados PASS en `2026-10-20e`: alta real vía Cloud Function en el emulador de Functions, correo duplicado, límite de plazas, activación del nuevo empleado).
- 2026-10-20 Android (API 36, emulator-5554), 1er pase (`2026-10-20d`): fallido por entorno — **almacenamiento interno del emulador lleno** (`INSTALL_FAILED_INSUFFICIENT_STORAGE`, partición /data 5,8 GB al 90 %) y servicio `package` caído; auth farmacia 3/7 antes de romperse. Solución: AVD recreado con `disk.dataPartition.size=12G` + `-wipe-data`; runner instala el APK antes de `pm grant`. 2º pase (`2026-10-20e`) falló porque el AVD de 12 GB no arrancó por falta de disco en el host ("not enough disk space to run avd"); 3º pase con partición de 8 GB (`2026-10-20f`): **auth farmacia, fichaje, fichaje sin ubicación y rendimiento PASS**; 4 archivos quedaron colgados (`No tests ran`, VM service) y chat con "device offline". Repasos (`g`, `h`, `i`): **gestión de empleados PASS** (alta real vía Cloud Function también en Android); auth empleado 7/8 (solo falló el overflow de la pantalla de inicio, BUG-016, ya corregido); smoke/chat/horarios/ausencias no llegaron a ejecutarse por `VmServiceDisappearedException`/"Unable to start the app" con el host a carga 60-77 (3 simuladores + gradle + emulador). Runner endurecido (`adb forward --remove-all`, `am force-stop`, instalación previa). 4º pase con emulador reiniciado en frío y host descargado: en ejecución (`2026-10-20j`).
- **Regresión iOS tras la Fase 8 (`2026-10-20h`)**: fichaje, horarios, empleados, auth empleado y ausencias **5/5 PASS** (47/47 tests de integración siguen verdes en iOS con las correcciones).
- **BUG-016 (media, UI, solo observado en Android)** — la pantalla de inicio desbordaba 28 px en el emulador 1080×2400 (en debug lanza excepción de layout; en release se recorta): `Column` con ilustración de 200 px sin scroll. Corregido (scroll + IntrinsicHeight) con widget test en 3 tamaños (`test/widgets/index_page_layout_test.dart`, rojo antes, verde después).
- **BUG-015 (alta en local / sin efecto en prod)** — todas las functions que usan `admin.firestore.FieldValue/Timestamp` fallan en el emulador (`createEmployeeAccount`: "reading 'serverTimestamp'"). Migradas a `require('firebase-admin/firestore')` (9 archivos); `npm test` 385 verdes.

## Próximas acciones
1. Terminar matriz de funcionalidades (workflow en curso).
2. Infraestructura de pruebas: emuladores Firebase (`firebase.json`), switch de emulador en `main.dart`/`CallableHttpClient`, cleartext solo debug en Android, `functions/.secret.local`.
3. Fase 2: buscadores estáticos por dimensión + verificación adversarial de `docs/qa/candidate_issues.json`.
4. Fase 3/4: integration_test en iPhone 18 Pro (iOS 27) y emulator-5554 (API 36) contra emuladores.

## Bloqueos encontrados
- **2026-10-17 ~21:55 — Disco lleno (ENOSPC)** durante las compilaciones iOS+Android (10 GB libres al empezar; `~/.gradle` 22 GB, DerivedData 14 GB). El build Android falló (`No space left on device`) y el harness no podía escribir. Resuelto borrando solo cachés regenerables: DerivedData de otros proyectos, cachés dyld de simuladores, distribuciones Gradle distintas de 8.14.3 y cachés Gradle de versiones no usadas, `functions/build` (artefactos accidentales). Resultado: 15 GB libres. No se tocaron Archives de Xcode, snapshots de AVD ni datos de usuario. Build Android relanzado.
- firebase-tools 15 exige Java 21 (sistema: 17) → resuelto con el JBR de Android Studio (ver Infraestructura).
- iOS: el simulador iPhone 18 Pro estaba apagado al lanzar el runner → el runner ahora lo arranca solo.
