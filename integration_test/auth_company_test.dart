// Autenticación de farmacia contra el emulador: validaciones, credenciales
// incorrectas, login correcto y llegada al dashboard.
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
      await waitForToast(tester, 'Por favor, rellena todos los campos');
      expect(find.text('Acceso para farmacias'), findsOneWidget);
    });

    testWidgets('AUTH-C-002 contraseña incorrecta → mensaje claro, sin datos técnicos', (tester) async {
      await launchApp(tester);
      await gotoCompanyLogin(tester);
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

    testWidgets('AUTH-C-002b evidencia: el SDK responde a una contraseña incorrecta en < 15 s', (tester) async {
      await launchApp(tester);
      final sw = Stopwatch()..start();
      Object? error;
      try {
        await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: Seed.companyPaidEmail, password: 'incorrecta-123')
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        error = e;
      }
      // ignore: avoid_print
      print('AUTH-C-002b: respuesta del SDK en ${sw.elapsedMilliseconds} ms → $error');
      expect(error, isNotNull, reason: 'una contraseña incorrecta debe fallar');
      expect(error, isNot(isA<TimeoutException>()), reason: 'el SDK no debe colgarse');
      expect(error, isA<FirebaseAuthException>());
      await FirebaseAuth.instance.signOut();
    });

    testWidgets('AUTH-C-003 email con formato inválido → no entra', (tester) async {
      await launchApp(tester);
      await gotoCompanyLogin(tester);
      await typeInto(tester, 'Correo electrónico', 'esto-no-es-un-email');
      await typeInto(tester, 'Contraseña', Seed.password);
      await tapText(tester, 'INICIAR SESIÓN');
      await waitForAnyToast(tester, [
        'El correo electrónico no es válido',
        'Correo o contraseña incorrectos',
      ], timeout: const Duration(seconds: 20));
      expect(find.text('Acceso para farmacias'), findsOneWidget);
    });

    testWidgets('AUTH-C-004 doble tap en INICIAR SESIÓN no rompe nada', (tester) async {
      await launchApp(tester);
      await gotoCompanyLogin(tester);
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
      // La tarjeta de la empresa está al final de un ListView (perezoso): scroll.
      await tester.scrollUntilVisible(
        find.textContaining(Seed.companyPaidName),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining(Seed.companyPaidName), findsWidgets);
      expect(tester.takeException(), isNull);
      // Pestaña Empleados: los empleados activos/pendientes aparecen; el borrado no.
      await tapNav(tester, 'Empleados');
      await waitFor(tester, find.text(Seed.empAnaName), timeout: const Duration(seconds: 20));
      expect(find.text('Luis Gómez'), findsWidgets);
      expect(find.text('Marta Ruiz'), findsWidgets);
      expect(find.text('Empleado Borrado'), findsNothing);
    });

    testWidgets('AUTH-C-006 cerrar sesión vuelve al inicio y limpia la sesión', (tester) async {
      await launchApp(tester);
      await tapNav(tester, 'Perfil');
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
