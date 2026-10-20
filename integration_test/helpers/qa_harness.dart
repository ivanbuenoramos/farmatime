// Harness común de las pruebas de integración de QA (iOS + Android).
//
// Las pruebas arrancan la app REAL (main.dart) contra el Firebase Emulator
// Suite. Hay que lanzarlas con:
//   flutter test integration_test/<archivo> -d <device> \
//     --dart-define=FIREBASE_EMULATOR_HOST=localhost   (iOS)   | =10.0.2.2 (Android)
// y con los emuladores arrancados y sembrados (tool/qa/seed_emulator.js).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

import 'package:farmatime/main.dart' as app;

/// Datos sembrados por tool/qa/seed_emulator.js (mantener sincronizados).
class Seed {
  static const password = 'Password123!';
  static const companyPaidEmail = 'farmacia.qa@farmatime.test';
  static const companyPaidName = 'Farmacia QA Central';
  static const companyFreeEmail = 'farmacia.gratis@farmatime.test';
  static const empAnaEmail = 'ana.qa@farmatime.test';
  static const empAnaName = 'Ana Pérez';
  static const empLuisEmail = 'luis.qa@farmatime.test';
  static const empMartaEmail = 'marta.qa@farmatime.test';
  static const empMartaTempPassword = 'temp1234A!';
  static const empSoloEmail = 'solo.qa@farmatime.test';
}

/// Host del Emulator Suite visto desde el dispositivo (pasado por --dart-define).
const String emulatorHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST');

/// Falla rápido y claro si alguien lanza la suite sin aislar el backend.
void requireEmulator() {
  if (emulatorHost.isEmpty) {
    fail('Las pruebas de integración exigen --dart-define=FIREBASE_EMULATOR_HOST '
        '(nunca se ejecutan contra producción).');
  }
}

bool _storageCleared = false;

/// Arranca la app. flutter_test desmonta el árbol de widgets al terminar cada
/// `testWidgets`, así que hay que volver a ejecutar `main()` (runApp cada vez);
/// Firebase/GetX ya están inicializados y `main()` es idempotente en ese caso.
/// La sesión local (GetStorage) solo se borra la PRIMERA vez por proceso, de
/// modo que los tests de un mismo archivo encadenan estado (login → acciones).
Future<void> launchApp(WidgetTester tester) async {
  requireEmulator();
  if (!_storageCleared) {
    _storageCleared = true;
    await GetStorage.init();
    await GetStorage().erase();
  }
  // main() instala su propio FlutterError.onError (logging de producción);
  // flutter_test necesita el suyo para capturar errores como fallos de test.
  final originalOnError = FlutterError.onError;
  await app.main();
  FlutterError.onError = originalOnError;
  // Splash (1 s) → inicio, o directamente el main del rol con sesión guardada.
  await waitForAny(tester, [
    find.text('ACCESO PARA FARMACIAS'),
    find.text('Trabajando'),
    find.text('Mi día'),
    find.text('Asignar contraseña'),
  ], timeout: const Duration(seconds: 30));
}

/// Bombea frames hasta que [finder] encuentre algo o venza [timeout].
/// A diferencia de pumpAndSettle, tolera animaciones infinitas (spinners).
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
  Duration step = const Duration(milliseconds: 100),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return;
  }
  // Volcado de ayuda para diagnosticar.
  final texts = find.byType(Text).evaluate()
      .map((e) => (e.widget as Text).data ?? '')
      .where((t) => t.isNotEmpty)
      .take(40)
      .toList();
  fail('Timeout esperando $finder. Textos visibles: $texts');
}

Future<Finder> waitForAny(
  WidgetTester tester,
  List<Finder> finders, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    for (final f in finders) {
      if (f.evaluate().isNotEmpty) return f;
    }
  }
  fail('Timeout esperando cualquiera de $finders');
}

/// Espera a que [finder] desaparezca.
Future<void> waitForGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isEmpty) return;
  }
  fail('Timeout: $finder sigue visible');
}

/// Bombea durante [d] en pasos cortos (deja correr timers y streams).
Future<void> pumpFor(WidgetTester tester, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Escribe en el TextField cuyo hint es [hint].
Future<void> typeInto(WidgetTester tester, String hint, String text) async {
  final field = find.widgetWithText(TextField, hint);
  await waitFor(tester, field);
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pump(const Duration(milliseconds: 150));
  await tester.enterText(field, text);
  await tester.pump(const Duration(milliseconds: 150));
}

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text);
  await waitFor(tester, f);
  await tester.ensureVisible(f.first);
  await tester.tap(f.first);
  await tester.pump(const Duration(milliseconds: 200));
}

/// Desde la pantalla de inicio, entra como farmacia.
Future<void> loginAsCompany(WidgetTester tester,
    {String email = Seed.companyPaidEmail, String password = Seed.password}) async {
  await tapText(tester, 'ACCESO PARA FARMACIAS');
  await waitFor(tester, find.text('Acceso para farmacias'));
  await typeInto(tester, 'Correo electrónico', email);
  await typeInto(tester, 'Contraseña', password);
  await tapText(tester, 'INICIAR SESIÓN');
}

/// Desde la pantalla de inicio, entra como empleado.
Future<void> loginAsEmployee(WidgetTester tester,
    {required String email, String password = Seed.password}) async {
  await tapText(tester, 'INICIAR SESIÓN');
  await waitFor(tester, find.text('¡Bienvenido!'));
  await typeInto(tester, 'Correo electrónico', email);
  await typeInto(tester, 'Contraseña', password);
  await tapText(tester, 'INICIAR SESIÓN');
}

/// Lee un documento del emulador de Firestore vía REST (bypass de reglas con
/// el token "owner"). Devuelve los campos en formato REST (typed values).
Future<Map<String, dynamic>?> emulatorGetDoc(String path) async {
  final uri = Uri.http('$emulatorHost:8080',
      '/v1/projects/farmatime-app/databases/(default)/documents/$path');
  final client = HttpClient();
  try {
    final req = await client.getUrl(uri);
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer owner');
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw StateError('GET $path → ${res.statusCode}: $body');
    }
    return json.decode(body) as Map<String, dynamic>;
  } finally {
    client.close();
  }
}

/// Ejecuta una consulta estructurada contra el emulador (REST runQuery) y
/// devuelve los documentos encontrados.
Future<List<Map<String, dynamic>>> emulatorRunQuery(Map<String, dynamic> structuredQuery) async {
  final uri = Uri.http('$emulatorHost:8080',
      '/v1/projects/farmatime-app/databases/(default)/documents:runQuery');
  final client = HttpClient();
  try {
    final req = await client.postUrl(uri);
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer owner');
    req.headers.contentType = ContentType.json;
    req.add(utf8.encode(json.encode({'structuredQuery': structuredQuery})));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) throw StateError('runQuery → ${res.statusCode}: $body');
    final list = json.decode(body) as List;
    return [
      for (final e in list)
        if (e is Map && e['document'] != null) Map<String, dynamic>.from(e['document'] as Map)
    ];
  } finally {
    client.close();
  }
}

/// Valor plano de un campo REST de Firestore ({stringValue: ..} → ..).
dynamic restValue(dynamic v) {
  if (v is! Map) return v;
  if (v.containsKey('stringValue')) return v['stringValue'];
  if (v.containsKey('integerValue')) return int.parse(v['integerValue'] as String);
  if (v.containsKey('doubleValue')) return (v['doubleValue'] as num).toDouble();
  if (v.containsKey('booleanValue')) return v['booleanValue'];
  if (v.containsKey('nullValue')) return null;
  if (v.containsKey('timestampValue')) return DateTime.parse(v['timestampValue'] as String);
  if (v.containsKey('mapValue')) {
    final fields = (v['mapValue']['fields'] ?? {}) as Map;
    return {for (final k in fields.keys) k: restValue(fields[k])};
  }
  if (v.containsKey('arrayValue')) {
    final values = (v['arrayValue']['values'] ?? []) as List;
    return values.map(restValue).toList();
  }
  return v;
}

Map<String, dynamic> restFields(Map<String, dynamic> doc) {
  final fields = (doc['fields'] ?? {}) as Map;
  return {for (final k in fields.keys) k.toString(): restValue(fields[k])};
}

/// Vuelca textos visibles (ayuda a depurar un fallo).
List<String> visibleTexts() => find.byType(Text).evaluate()
    .map((e) => (e.widget as Text).data ?? '')
    .where((t) => t.trim().isNotEmpty)
    .toList();

/// Pequeña utilidad para `unawaited`-style sin importar dart:async en tests.
void ignore(Future<void> f) => unawaited(f);

/// Lista los documentos de una colección del emulador (REST, bypass de reglas).
Future<List<Map<String, dynamic>>> emulatorListDocs(String collectionPath) async {
  final uri = Uri.http('$emulatorHost:8080',
      '/v1/projects/farmatime-app/databases/(default)/documents/$collectionPath');
  final client = HttpClient();
  try {
    final req = await client.getUrl(uri);
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer owner');
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) throw StateError('LIST $collectionPath → ${res.statusCode}: $body');
    final decoded = json.decode(body) as Map<String, dynamic>;
    final docs = (decoded['documents'] ?? []) as List;
    return [for (final d in docs) Map<String, dynamic>.from(d as Map)];
  } finally {
    client.close();
  }
}

/// Fichajes (clockRecords) de un empleado, leídos del emulador.
Future<List<Map<String, dynamic>>> clockRecordsOf(String employeeUid) async {
  final docs = await emulatorRunQuery({
    'from': [{'collectionId': 'clockRecords'}],
    'where': {
      'fieldFilter': {
        'field': {'fieldPath': 'employeeId'},
        'op': 'EQUAL',
        'value': {'stringValue': employeeUid},
      },
    },
  });
  return docs.map(restFields).toList();
}

/// Localiza un widget privado por el nombre de su tipo (p. ej. '_SummaryMetric').
Finder byTypeName(String typeName) =>
    find.byWidgetPredicate((w) => w.runtimeType.toString() == typeName);

/// Texto del valor de una métrica del dashboard (widget privado _SummaryMetric
/// = Column con Text(valor) + Text(label)).
String? dashboardMetricValue(String label) {
  final metric = find.ancestor(of: find.text(label), matching: byTypeName('_SummaryMetric'));
  if (metric.evaluate().isEmpty) return null;
  final texts = find.descendant(of: metric.first, matching: find.byType(Text))
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .whereType<String>()
      .toList();
  texts.remove(label);
  return texts.isEmpty ? null : texts.first;
}
