// Fichaje con el permiso de ubicación DENEGADO/REVOCADO (el runner revoca el
// permiso antes de lanzar este archivo): la app debe avisar y registrar el
// fichaje sin coordenadas, nunca bloquear ni crashear.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/qa_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CLOCK-DENIED-001 permiso de ubicación denegado → aviso y fichaje sin ubicación', (tester) async {
    await launchApp(tester);
    await loginAsEmployee(tester, email: Seed.empLuisEmail);
    await waitFor(tester, find.text('¡Hola, Luis!'), timeout: const Duration(seconds: 40));
    await waitFor(tester, find.text('FICHAR ENTRADA'), timeout: const Duration(seconds: 20));
    await tapText(tester, 'FICHAR ENTRADA');
    // Aviso en lenguaje natural (denegado, bloqueado o servicio apagado).
    await waitForAny(tester, [
      find.text('Permiso denegado'),
      find.text('Permiso bloqueado'),
      find.text('Ubicación desactivada'),
      find.text('Error ubicación'),
    ], timeout: const Duration(seconds: 30));
    await waitFor(tester, find.text('FICHAR SALIDA'), timeout: const Duration(seconds: 30));
    await pumpFor(tester, const Duration(seconds: 1));
    final records = await clockRecordsOf('qa-emp-luis');
    expect(records.length, 1);
    expect(records.single['clockInLat'], isNull);
    expect(records.single['clockInLng'], isNull);
    expect(tester.takeException(), isNull);
    // Cierra el turno para dejar el estado limpio.
    await tapText(tester, 'FICHAR SALIDA');
    await waitFor(tester, find.text('FICHAR ENTRADA'), timeout: const Duration(seconds: 30));
    await tapText(tester, 'Perfil');
    await waitFor(tester, find.text('Mi cuenta'));
    await tapText(tester, 'Cerrar sesión');
    await waitFor(tester, find.text('¿Seguro que quieres cerrar sesión?'));
    await tester.tap(find.widgetWithText(TextButton, 'Cerrar sesión').last);
    await waitFor(tester, find.text('ACCESO PARA FARMACIAS'), timeout: const Duration(seconds: 20));
  });
}
