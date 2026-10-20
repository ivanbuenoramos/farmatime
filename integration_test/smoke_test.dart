// Smoke: la app arranca contra el emulador, llega a la pantalla de inicio y la
// navegación básica (inicio ↔ accesos) funciona en ambas plataformas.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/qa_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('SMOKE', () {
    testWidgets('SMOKE-001 arranca y muestra la pantalla de inicio', (tester) async {
      await launchApp(tester);
      expect(find.text('ACCESO PARA FARMACIAS'), findsOneWidget);
      expect(find.text('INICIAR SESIÓN'), findsOneWidget);
      expect(find.text('¡Hola!'), findsOneWidget);
    });

    testWidgets('SMOKE-002 acceso farmacias: ir y volver atrás', (tester) async {
      await launchApp(tester);
      await tapText(tester, 'ACCESO PARA FARMACIAS');
      await waitFor(tester, find.text('Acceso para farmacias'));
      expect(find.widgetWithText(TextField, 'Correo electrónico'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Contraseña'), findsOneWidget);
      expect(find.text('Crear cuenta de farmacia'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await waitFor(tester, find.text('ACCESO PARA FARMACIAS'));
    });

    testWidgets('SMOKE-003 acceso empleados: ir y volver atrás', (tester) async {
      await launchApp(tester);
      await tapText(tester, 'INICIAR SESIÓN');
      await waitFor(tester, find.text('¡Bienvenido!'));
      expect(find.text('Recuperarla aquí'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await waitFor(tester, find.text('ACCESO PARA FARMACIAS'));
    });

    testWidgets('SMOKE-004 recuperar contraseña: ir y volver', (tester) async {
      await launchApp(tester);
      await tapText(tester, 'INICIAR SESIÓN');
      await waitFor(tester, find.text('¡Bienvenido!'));
      await tapText(tester, 'Recuperarla aquí');
      // La pantalla debe aparecer sin excepciones; volvemos.
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      expect(find.text('¡Bienvenido!'), findsNothing, reason: 'debe haber navegado a recuperar contraseña');
      await backToIndex(tester);
    });
  });
}
