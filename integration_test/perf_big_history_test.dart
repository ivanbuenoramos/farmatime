// Rendimiento / listas extensas: Luis tiene miles de fichajes históricos
// (semilla --big). La app debe seguir arrancando "Mi día" y la pestaña
// "Fichajes" sin excepciones y en un tiempo razonable. Mide y registra tiempos.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/qa_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PERF-001 empleado con miles de fichajes: Mi día y Fichajes cargan sin fallos', (tester) async {
    await launchApp(tester);
    // Siembra masiva (si el runner no la hizo): consultamos cuántos hay.
    final existing = await clockRecordsOf('qa-emp-luis');
    stdout.writeln('PERF: fichajes históricos de Luis en el emulador = ${existing.length}');
    expect(existing.length, greaterThanOrEqualTo(1000),
        reason: 'ejecutar la semilla con --big (tool/qa/seed_emulator.js --big)');

    final sw = Stopwatch()..start();
    await loginAsEmployee(tester, email: Seed.empLuisEmail);
    await waitFor(tester, find.text('¡Hola, Luis!'), timeout: const Duration(seconds: 60));
    await waitFor(tester, find.text('FICHAR ENTRADA'), timeout: const Duration(seconds: 60));
    final loginMs = sw.elapsedMilliseconds;
    stdout.writeln('PERF: login + Mi día listo en $loginMs ms');
    expect(tester.takeException(), isNull);

    sw.reset();
    await tapNav(tester, 'Fichajes');
    // La pestaña carga el histórico completo; esperamos a que aparezca algún día.
    await pumpFor(tester, const Duration(seconds: 2));
    final end = DateTime.now().add(const Duration(seconds: 60));
    while (DateTime.now().isBefore(end) && find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    final entriesMs = sw.elapsedMilliseconds;
    stdout.writeln('PERF: pestaña Fichajes sin spinner en $entriesMs ms');
    expect(tester.takeException(), isNull);
    // Scroll largo por la lista: no debe lanzar excepciones.
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isNotEmpty) {
      for (var i = 0; i < 15; i++) {
        await tester.drag(scrollable.first, const Offset(0, -1200));
        await tester.pump(const Duration(milliseconds: 120));
      }
    }
    expect(tester.takeException(), isNull);
    expect(loginMs, lessThan(45000), reason: 'login con histórico masivo demasiado lento');
    expect(entriesMs, lessThan(45000), reason: 'listado de fichajes demasiado lento');

    await tapNav(tester, 'Mi día');
    await logoutEmployee(tester);
  });
}
