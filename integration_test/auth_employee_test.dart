// Autenticación de empleado contra el emulador: activación con contraseña
// temporal (pending → active), login normal, formularios cruzados y logout.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/qa_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('AUTH-EMPLOYEE', () {
    testWidgets('AUTH-E-001 empleado pendiente: login con contraseña temporal → asignar contraseña', (tester) async {
      await launchApp(tester);
      await loginAsEmployee(tester, email: Seed.empMartaEmail, password: Seed.empMartaTempPassword);
      await waitFor(tester, find.text('Asignar contraseña'), timeout: const Duration(seconds: 40));
      expect(tester.takeException(), isNull);
    });

    testWidgets('AUTH-E-002 asignar contraseña: validaciones (vacía, corta, no coincide)', (tester) async {
      await launchApp(tester);
      await waitFor(tester, find.text('Asignar contraseña'));
      await tapText(tester, 'Guardar cambios');
      await waitFor(tester, find.text('Introduce la nueva contraseña'));
      await tester.enterText(find.widgetWithText(TextFormField, 'Nueva contraseña'), '123');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirmar nueva contraseña'), '123');
      await tapText(tester, 'Guardar cambios');
      await waitFor(tester, find.text('Debe tener al menos 6 caracteres'));
      await tester.enterText(find.widgetWithText(TextFormField, 'Nueva contraseña'), 'NuevaPass1!');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirmar nueva contraseña'), 'Otra1!');
      await tapText(tester, 'Guardar cambios');
      await waitFor(tester, find.text('Las contraseñas no coinciden'));
      expect(find.text('Asignar contraseña'), findsOneWidget);
    });

    testWidgets('AUTH-E-003 asignar contraseña válida → cuenta activa y entra en Mi día', (tester) async {
      await launchApp(tester);
      await waitFor(tester, find.text('Asignar contraseña'));
      await tester.enterText(find.widgetWithText(TextFormField, 'Nueva contraseña'), Seed.password);
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirmar nueva contraseña'), Seed.password);
      await tapText(tester, 'Guardar cambios');
      await waitFor(tester, find.text('¡Hola, Marta!'), timeout: const Duration(seconds: 40));
      expect(find.text('Mi día'), findsOneWidget);
      // Verificación de datos en el backend (emulador): pending → active, sin temp.
      final doc = await emulatorGetDoc('employees/qa-emp-marta');
      expect(doc, isNotNull);
      final fields = restFields(doc!);
      expect(fields['accountStatus'], 'active');
      expect(fields['hasTempPassword'], false);
      expect(fields['companyId'], 'qa-company-paid', reason: 'companyId no debe cambiar');
      expect(tester.takeException(), isNull);
    });

    testWidgets('AUTH-E-004 cerrar sesión (con confirmación) vuelve al inicio', (tester) async {
      await launchApp(tester);
      await logoutEmployee(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AUTH-E-005 la contraseña temporal ya no vale tras activar', (tester) async {
      await launchApp(tester);
      await loginAsEmployee(tester, email: Seed.empMartaEmail, password: Seed.empMartaTempPassword);
      await waitFor(tester, find.text('Correo o contraseña incorrectos'), timeout: const Duration(seconds: 20));
      await goBack(tester);
      await waitFor(tester, find.text('ACCESO PARA FARMACIAS'));
    });

    testWidgets('AUTH-E-006 empleado activo entra directo a Mi día', (tester) async {
      await launchApp(tester);
      await loginAsEmployee(tester, email: Seed.empAnaEmail);
      await waitFor(tester, find.text('¡Hola, Ana!'), timeout: const Duration(seconds: 40));
      expect(find.text('Fichajes'), findsOneWidget);
      expect(find.text('Calendario'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await logoutEmployee(tester);
    });

    testWidgets('AUTH-E-007 formulario cruzado: empleado en acceso de farmacias entra como empleado', (tester) async {
      await launchApp(tester);
      await loginAsCompany(tester, email: Seed.empAnaEmail, password: Seed.password);
      await waitFor(tester, find.text('¡Hola, Ana!'), timeout: const Duration(seconds: 40));
      await logoutEmployee(tester);
    });

    testWidgets('AUTH-E-008 formulario cruzado: farmacia en acceso de empleados entra como farmacia', (tester) async {
      await launchApp(tester);
      await loginAsEmployee(tester, email: Seed.companyPaidEmail, password: Seed.password);
      await waitFor(tester, find.text('Trabajando'), timeout: const Duration(seconds: 40));
      await tapNav(tester, 'Perfil');
      await tapText(tester, 'Cerrar sesión');
      await waitFor(tester, find.text('ACCESO PARA FARMACIAS'), timeout: const Duration(seconds: 20));
    });
  });
}
