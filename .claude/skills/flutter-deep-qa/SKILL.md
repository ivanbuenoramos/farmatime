---
name: flutter-deep-qa
description: Auditoría QA profunda y repetible de Farmatime (Flutter + Firebase) en iOS y Android — metodología por fases, categorías de errores, comandos de prueba (analyze/test/integration/reglas/functions), matriz de dispositivos, estados de permisos, criterios de aceptación y ciclos de regresión. Usar para re-auditar tras cada actualización o para añadir pruebas a una funcionalidad.
---

# flutter-deep-qa — Auditoría QA profunda de Farmatime

Metodología para auditar, probar y corregir Farmatime (app Flutter 3.47.x + GetX + Firebase)
en **iOS y Android reales (simulador/emulador)**, sin tocar datos de producción.
La primera auditoría completa se hizo el 2026-10-17 en la rama `audit/flutter-deep-qa-2026-10`
(informe en `QA_AUDIT_REPORT.md`, progreso en `QA_PROGRESS.md`, matriz en `docs/qa/`).

## 0. Principios

- **Nada contra producción.** La app se ejecuta contra el Firebase Emulator Suite
  (`--dart-define=FIREBASE_EMULATOR_HOST=…`). Jamás `firebase deploy`, ni pagos, ni pushes reales.
- **Verificado ≠ parece correcto.** Una funcionalidad solo se marca verificada si una prueba
  ejecutada la valida (unit, widget, integración en dispositivo, o reglas en emulador).
- **Un bug = una prueba que falla antes y pasa después.** Corrección mínima; sin try/catch vacíos,
  sin quitar funcionalidad, sin bajar cobertura, sin cambiar reglas de negocio sin evidencia.
- **Proteger el trabajo previo.** Rama propia `audit/<tema>-<fecha>` y commit de checkpoint antes de tocar nada.
- **Decisiones de producto ya tomadas (no re-proponer):** fichajes abiertos de días previos no se
  autocierran; ausencias pueden solaparse; `createEmployeeAccount` da 0 plazas sin `contractedSeats`
  (cliente asume 1 gratis); enlace bienvenida `https://farmatime.net/onboarding`; `CallableHttpClient`
  es un workaround intencionado (crash nativo iOS de `httpsCallable`).

## 1. Fases

| Fase | Qué | Salida |
|------|-----|--------|
| 0 Preparación | Leer docs/memoria, inventario de toolchain y dispositivos, rama + checkpoint | `QA_PROGRESS.md` |
| 1 Descubrimiento | Lectores por subsistema → pantallas, controladores, dataOps, roles, casos | `docs/qa/FUNCTIONALITY_MATRIX.md`, `discovery.json`, `candidate_issues.json` |
| 2 Estático | `flutter analyze`, `flutter test`, eslint functions, buscadores por dimensión + verificación adversarial (3 lentes) | issues confirmados con severidad |
| 3 Automatización | unit / widget / integration_test / reglas Firestore / functions | `test/`, `integration_test/`, `functions/test/` |
| 4 Funcional | Ejecutar en iOS + Android: cada pantalla, datos válidos/inválidos/vacíos/extremos, repetidos, atrás, salir/volver, persistencia, logs | resultados en `docs/qa/results/` |
| 5 Adverso | Sin red, lenta, timeouts, JSON malo, nulos, listas vacías/miles, dobles taps, navegación durante async, background, sesión caducada, permisos denegados/revocados | idem |
| 6 Seguridad | Reglas (tests unitarios en emulador), escalada, secretos, logs, validación servidor | sección de riesgos |
| 7 Rendimiento | Arranque, jank, rebuilds, memoria, listas, consultas redundantes (DevTools / `--profile`) | observado vs sospecha |
| 8 Corrección | Documentar → severidad → causa raíz → test rojo → fix mínimo → test verde → relacionados → sin regresión | commits atómicos |
| 9 Regresión | analyze + unit + widget + integración pertinente + build Android + build iOS | checklist §6 |
| 10 Informe | `QA_AUDIT_REPORT.md` con evidencias | — |

## 2. Categorías de errores (clasificar siempre)

Severidad: **Crítica** (crash, pérdida/corrupción de datos, escalada de privilegios, pago/estado
de suscripción incorrecto, bloqueo total), **Alta** (funcionalidad principal rota o estado
inconsistente visible, fuga de datos personales), **Media** (fallo recuperable, UX engañosa,
validación insuficiente sin impacto en datos), **Baja** (cosmética, logs, deprecaciones).

Categorías: null-safety · excepción sin controlar · BuildContext tras await · Rx/setState tras
dispose · race condition · Future/Stream sin await/cancelar · listener/controller sin dispose ·
navegación · gestión de estado GetX (bindings, `Get.find` sin registrar) · serialización
(`fromJson`/Timestamp vs String) · conversión de tipos · validación de entrada · operación duplicada
(doble tap) · concurrencia (transacciones Firestore) · autenticación · autorización (reglas vs
cliente) · tokens · datos sensibles (logs, Storage, repo) · dependencia vulnerable · fechas/zonas
horarias/medianoche · plataforma específica (iOS/Android).

## 3. Entorno y dispositivos

```bash
export PATH="$PATH:$HOME/Development/flutter/bin:$HOME/Library/Android/sdk/platform-tools:$HOME/Library/Android/sdk/emulator"
flutter doctor -v          # Flutter 3.47.6 · Xcode 27 · Android SDK 36 · Java 17
flutter devices && flutter emulators
xcrun simctl list devices available      # runtimes iOS 18.5 / 26.4 / 26.5 / 27.0
emulator -list-avds                      # Medium_Phone_API_36.0 · flutter_emulator (ambos API 36)
```

Matriz mínima por auditoría: iPhone pequeño (16e, iOS 18.5) · iPhone grande (17 Pro Max, iOS 26.5/27) ·
iPad (Pro 13", iOS 27) · Android teléfono API 36 (1080×2400) · Android pantalla distinta (AVD
`flutter_emulator` 1080×1920 o un AVD tablet creado con la misma imagen). Documentar siempre qué
versiones NO estaban disponibles (p. ej. imágenes Android < API 36 no instaladas).

Arrancar: `xcrun simctl boot <UDID>` · `emulator -avd Medium_Phone_API_36.0 &` (API 30: `emulator -avd qa_api30_small`).
Matriz ejecutada el 2026-10-20: iPhone 18 Pro/iOS 27 (suite completa), iPhone 16e/iOS 18.5, iPad Pro 13"/iOS 27,
Android 16/API 36 (suite completa), Android 11/API 30. Un solo dispositivo a la vez (datos del emulador compartidos).
OJO zsh: pasar los archivos al runner como argumentos explícitos (una variable `$FILES` no se divide en palabras).

## 4. Backend aislado: Firebase Emulator Suite

```bash
cd functions && npm ci                                     # Node 24 local (engines: 20 → avisos, funciona)
firebase emulators:start --only auth,firestore,functions,storage --project farmatime-app
# UI en http://localhost:4000 · Auth 9099 · Firestore 8080 · Functions 5001 · Storage 9199
```

- Secretos: `functions/.secret.local` con valores ficticios (ignorado por git). Sin él, el emulador
  intentaría leer Secret Manager de producción.
- Email (SendGrid) y push (FCM) no salen del emulador: la function debe tolerar su fallo.
- Semillas: `tool/qa/seed_emulator.sh` (REST con `Authorization: Bearer owner`) o el propio flujo de la app.
- Reset entre pruebas: `curl -X DELETE "http://localhost:8080/emulator/v1/projects/farmatime-app/databases/(default)/documents"`
  y `curl -X DELETE "http://localhost:9099/emulator/v1/projects/farmatime-app/accounts"`.

La app se conecta con `--dart-define=FIREBASE_EMULATOR_HOST=localhost` (iOS) o
`=10.0.2.2` (emulador Android). Sin ese define, la app usa producción: **no ejecutar la auditoría sin él**.

## 5. Comandos de prueba

```bash
# Estático
flutter analyze                       # criterio: 0 errores, 0 warnings (infos de deprecación documentados)
(cd functions && npm run lint)        # criterio: 0 errores

# Unit + widget
flutter test                          # test/**  (unit + widget) — criterio: 100 % verde
flutter test --coverage && genhtml coverage/lcov.info -o coverage/html   # cobertura (lcov vía brew)

# Reglas de seguridad Firestore/Storage (emulador)
(cd functions && npm test)            # mocha: test/rules/*.spec.js + test/unit/*.spec.js (arranca emulador con emulators:exec)

# Integración real en dispositivo (requiere emuladores Firebase arrancados)
flutter test integration_test -d <UDID iOS>     --dart-define=FIREBASE_EMULATOR_HOST=localhost
flutter test integration_test -d emulator-5554  --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2
# o todo junto, guardando resultados por plataforma:
tool/qa/run_integration_tests.sh [ios|android|all]

# Builds
flutter build apk --debug           # Android
flutter build ios --simulator --debug  # iOS (sin firma)
```

### Estados de permisos (sin Patrol)

```bash
# iOS (simulador)
xcrun simctl privacy <UDID> grant  location-always net.farmatime.app
xcrun simctl privacy <UDID> revoke location      net.farmatime.app   # → denegado, sin diálogo
xcrun simctl privacy <UDID> reset  all           net.farmatime.app   # → "no determinado" (vuelve el diálogo)
xcrun simctl location <UDID> set 40.4168,-3.7038                     # ubicación simulada
xcrun simctl push <UDID> net.farmatime.app payload.apns              # notificación push simulada
# Android (emulador)
adb shell pm grant  net.farmatime.app android.permission.ACCESS_FINE_LOCATION
adb shell pm revoke net.farmatime.app android.permission.ACCESS_FINE_LOCATION
adb shell pm grant  net.farmatime.app android.permission.POST_NOTIFICATIONS
adb emu geo fix -3.7038 40.4168
adb shell settings put secure location_mode 0        # servicio de ubicación apagado
adb shell svc wifi disable && adb shell svc data disable   # sin red (enable para volver)
adb shell am kill net.farmatime.app                  # matar en background
```

Patrol (4.10, compatible con Flutter ≥3.32) se evaluó: aporta interacción con diálogos nativos,
pero exige modificar el proyecto nativo (target de UI tests en Xcode, runner de instrumentación)
y una CLI global. Los estados de permiso se cubren de forma determinista con `simctl privacy` /
`adb pm`, así que no se añadió. Si en el futuro hace falta pulsar diálogos nativos, añadir
`patrol` como dev_dependency y seguir https://patrol.leancode.co/getting-started.

### Lecciones del harness de integración (aprendidas el 2026-10-17/20)

- `flutter_test` **desmonta la app al terminar cada `testWidgets`**: el harness vuelve a ejecutar
  `app.main()` en cada test (`launchApp`). Por eso `main()` es idempotente (`Firebase.apps.isEmpty`,
  `FirebaseEmulator` con flag) y cada test navega desde el inicio o desde el main del rol
  (la sesión persiste en GetStorage; solo se borra la primera vez por proceso).
- `main()` instala `FlutterError.onError`; el harness lo **restaura** tras `app.main()` o
  flutter_test aborta con "A test overrode FlutterError.onError".
- Un test colgado (`tearDownAll did not complete`) bloqueó el runner 2 días → watchdog por
  archivo (`FILE_TIMEOUT`, 1500 s por defecto).
- Nunca `tester.pumpAndSettle()` con spinners: usar `waitFor/waitForAny/pumpFor`.
- **Toasts**: el overlay de toastification solo es visible en la primera instancia de la app por
  proceso; las aserciones usan `ToastService.history` (`waitForToast`/`waitForAnyToast`).
- **Taps**: `tapText` solo toca widgets *hit-testable* (los IndexedStack mantienen las pestañas
  ocultas en el árbol y `find.text` las encuentra); barra inferior con `tapNav`; atrás con `goBack`.
- Los textos de la lista de un `ListView` perezoso no existen hasta hacer scroll (`scrollUntilVisible`).
- Verificar SIEMPRE el efecto en el backend por REST del emulador (`emulatorGetDoc`,
  `emulatorRunQuery`, `Authorization: Bearer owner`), no solo la UI.
- Semilla `--big` (3000 fichajes de Luis) para `perf_*`: el runner la aplica automáticamente.
- iOS y Android **no pueden correr a la vez** contra el mismo Emulator Suite (cada archivo resetea
  y siembra los datos).

## 6. Criterios de aceptación / cierre de auditoría

1. Todas las funcionalidades de la matriz auditadas o con limitación documentada.
2. 0 bugs críticos conocidos sin resolver.
3. `flutter analyze` sin errores ni warnings; `flutter test` 100 % verde; reglas y functions verdes.
4. Integración ejecutada en iOS y Android con resultados guardados en `docs/qa/results/<fecha>/`.
5. `flutter build apk --debug` y `flutter build ios --simulator` correctos.
6. Lo no verificable (IAP real, push real, email real, dispositivos no disponibles) documentado.
7. `QA_AUDIT_REPORT.md` con evidencias (salida de comandos, ids de prueba, commits).

## 7. Ciclo de regresión (tras cada conjunto de correcciones)

```bash
flutter analyze && flutter test && (cd functions && npm run lint && npm test) \
  && tool/qa/run_integration_tests.sh all \
  && flutter build apk --debug && flutter build ios --simulator --debug
```
Si algo falla: investigar causa raíz (¿regresión del fix o fallo preexistente?), corregir, repetir.
Registrar cada ciclo en `QA_PROGRESS.md`. Repetir la auditoría completa tras cada actualización
relevante reutilizando `docs/qa/FUNCTIONALITY_MATRIX.md` como checklist.

## 8. Plantilla de registro de bug

```
ID · Título · Severidad · Categoría · Plataforma (iOS/Android/ambas/backend)
Ubicación: archivo:línea
Causa raíz:
Reproducción (prueba): test/... o integration_test/... (falla antes: sí/no)
Corrección: commit <hash> (mínima, sin cambiar reglas de negocio)
Verificación: comando + resultado · Regresión: analyze/test/integración OK
```
