// Autenticación de farmacia contra el emulador: validaciones, credenciales
// incorrectas, login correcto y llegada al dashboard.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/qa_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('AUTH-COMPANY', () {
    testWidgets('AUTH-C-001 campos vacíos → aviso y sigue en la pantalla', (tester) async {
      await launchApp(tester);
      await tapText(tester, 'ACCESO PARA FARMACIAS');
      await waitFor(tester, find.text('Acceso para farmacias'));
      await tapText(tester, 'INICIAR SESIÓN');
      await waitFor(tester, find.text('Por favor, rellena todos los campos'));
      expect(find.text('Acceso para farmacias'), findsOneWidget);
    });

    testWidgets('AUTH-C-002 contraseña incorrecta → mensaje claro, sin datos técnicos', (tester) async {
      await launchApp(tester);
      await waitFor(tester, find.text('Acceso para farmacias'));
      await typeInto(tester, 'Correo electrónico', Seed.companyPaidEmail);
      await typeInto(tester, 'Contraseña', 'incorrecta-123');
      await tapText(tester, 'INICIAR SESIÓN');
      await waitFor(tester, find.text('Correo o contraseña incorrectos'),
          timeout: const Duration(seconds: 20));
      // Nunca se enseñan códigos crudos de Firebase.
      expect(find.textContaining('firebase_auth'), findsNothing);
      expect(find.textContaining('invalid-credential'), findsNothing);
      expect(find.text('Acceso para farmacias'), findsOneWidget);
    });

    testWidgets('AUTH-C-003 email con formato inválido → no entra', (tester) async {
      await launchApp(tester);
      await waitFor(tester, find.text('Acceso para farmacias'));
      await typeInto(tester, 'Correo electrónico', 'esto-no-es-un-email');
      await typeInto(tester, 'Contraseña', Seed.password);
      await tapText(tester, 'INICIAR SESIÓN');
      await waitForAny(tester, [
        find.text('El correo electrónico no es válido'),
        find.text('Correo o contraseña incorrectos'),
      ], timeout: const Duration(seconds: 20));
      expect(find.text('Acceso para farmacias'), findsOneWidget);
    });

    testWidgets('AUTH-C-004 doble tap en INICIAR SESIÓN no rompe nada', (tester) async {
      await launchApp(tester);
      await waitFor(tester, find.text('Acceso para farmacias'));
      await typeInto(tester, 'Correo electrónico', Seed.companyPaidEmail);
      await typeInto(tester, 'Contraseña', Seed.password);
      final btn = find.text('INICIAR SESIÓN');
      await tester.tap(btn);
      await tester.pump(const Duration(milliseconds: 30));
      // Segundo tap inmediato: el botón debe estar deshabilitado/cargando.
      if (btn.evaluate().isNotEmpty) {
        await tester.tap(btn, warnIfMissed: false);
      }
      // Llegada al dashboard de farmacia.
      await waitFor(tester, find.text('Trabajando'), timeout: const Duration(seconds: 40));
      expect(tester.takeException(), isNull);
      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text('Empleados'), findsWidgets);
      expect(find.text('Perfil'), findsOneWidget);
    });

    testWidgets('AUTH-C-005 el dashboard muestra la empresa y sus empleados', (tester) async {
      await launchApp(tester);
      await waitFor(tester, find.text('Trabajando'));
      // Deja que lleguen los streams de Firestore.
      await pumpFor(tester, const Duration(seconds: 3));
      expect(find.textContaining(Seed.companyPaidName), findsWidgets);
      expect(tester.takeException(), isNull);
      // Pestaña Empleados: los empleados activos/pendientes aparecen; el borrado no.
      await tapText(tester, 'Empleados');
      await waitFor(tester, find.text(Seed.empAnaName), timeout: const Duration(seconds: 20));
      expect(find.text('Luis Gómez'), findsWidgets);
      expect(find.text('Marta Ruiz'), findsWidgets);
      expect(find.text('Empleado Borrado'), findsNothing);
    });

    testWidgets('AUTH-C-006 cerrar sesión vuelve al inicio y limpia la sesión', (tester) async {
      await launchApp(tester);
      await tapText(tester, 'Perfil');
      await pumpFor(tester, const Duration(seconds: 1));
      await tapText(tester, 'Cerrar sesión');
      // Puede haber confirmación.
      await pumpFor(tester, const Duration(milliseconds: 500));
      final confirm = find.text('Cerrar sesión');
      if (confirm.evaluate().length > 1) {
        await tester.tap(confirm.last);
      } else {
        final si = find.text('Sí');
        if (si.evaluate().isNotEmpty) await tester.tap(si.first);
      }
      await waitFor(tester, find.text('ACCESO PARA FARMACIAS'), timeout: const Duration(seconds: 20));
      expect(tester.takeException(), isNull);
    });
  });
}
