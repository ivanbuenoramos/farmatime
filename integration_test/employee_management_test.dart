// Gestión de empleados (farmacia) contra el emulador: alta real vía la
// Cloud Function createEmployeeAccount (emulador de Functions), validaciones,
// correo duplicado, límite de plazas y activación del nuevo empleado.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/qa_harness.dart';

const _newEmail = 'nuevo.qa@farmatime.test';

Future<void> _openNewEmployeeForm(WidgetTester tester) async {
  await tapNav(tester, 'Empleados');
  await waitFor(tester, find.text('Lista de empleados'));
  await waitFor(tester, find.text(Seed.empAnaName), timeout: const Duration(seconds: 20));
  await tester.tap(find.byType(FloatingActionButton));
  await waitFor(tester, find.text('Nuevo empleado'));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('EMPLOYEES', () {
    testWidgets('EMP-001 formulario vacío → aviso de validación', (tester) async {
      await launchApp(tester);
      await loginAsCompany(tester);
      await waitFor(tester, find.text('Trabajando'), timeout: const Duration(seconds: 40));
      await _openNewEmployeeForm(tester);
      await tapText(tester, 'Crear empleado');
      await waitForToast(tester, 'Por favor, introduce un nombre y correo válidos.');
      expect(find.text('Nuevo empleado'), findsWidgets);
    });

    testWidgets('EMP-002 correo ya en uso → "Correo en uso" y no se crea', (tester) async {
      await launchApp(tester);
      await _openNewEmployeeForm(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Nombre del empleado'), 'Duplicado QA');
      await tester.enterText(find.widgetWithText(TextField, 'Correo electrónico'), Seed.empAnaEmail);
      // Deja actuar al debounce (600 ms) + callable checkEmployeeEmailAvailability.
      await pumpFor(tester, const Duration(seconds: 3));
      await tapText(tester, 'Crear empleado');
      await waitForToast(tester, 'Correo en uso', timeout: const Duration(seconds: 20));
      expect(find.text('Nuevo empleado'), findsWidgets);
    });

    testWidgets('EMP-003 tarifa negativa → aviso', (tester) async {
      await launchApp(tester);
      await _openNewEmployeeForm(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Correo electrónico'), _newEmail);
      await pumpFor(tester, const Duration(seconds: 3));
      final rate = find.widgetWithText(TextField, 'Precio por hora');
      await tester.ensureVisible(rate);
      await tester.enterText(rate, '-5');
      await tapText(tester, 'Crear empleado');
      await waitForToast(tester, 'El precio por hora no puede ser negativo.', timeout: const Duration(seconds: 20));
      await tester.enterText(rate, '12,50');
    });

    testWidgets('EMP-004 alta válida → Cloud Function crea Auth + doc pending + credenciales privadas', (tester) async {
      await launchApp(tester);
      await _openNewEmployeeForm(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Nombre del empleado'), 'Nuevo QA');
      await tester.enterText(find.widgetWithText(TextField, 'Correo electrónico'), _newEmail);
      await pumpFor(tester, const Duration(seconds: 3));
      await tapText(tester, 'Crear empleado');
      await waitForToast(tester, 'Empleado creado', timeout: const Duration(seconds: 40));
      // Vuelve a la lista y aparece el nuevo empleado como Pendiente.
      await waitFor(tester, find.text('Lista de empleados'), timeout: const Duration(seconds: 20));
      await waitFor(tester, find.text('Nuevo QA'), timeout: const Duration(seconds: 20));
      expect(tester.takeException(), isNull);

      // Backend (emulador): doc por uid real, estado pending, sin tempPassword
      // en el doc principal, credenciales en subcolección privada, reserva borrada.
      final docs = await emulatorRunQuery({
        'from': [{'collectionId': 'employees'}],
        'where': {'fieldFilter': {'field': {'fieldPath': 'email'}, 'op': 'EQUAL', 'value': {'stringValue': _newEmail}}},
      });
      expect(docs.length, 1, reason: 'solo debe quedar el doc definitivo (sin reserva temporal)');
      final emp = restFields(docs.single);
      final uid = (docs.single['name'] as String).split('/').last;
      expect(emp['uid'], uid);
      expect(emp['companyId'], 'qa-company-paid');
      expect(emp['accountStatus'], 'pending');
      expect(emp['hasTempPassword'], true);
      expect(emp.containsKey('tempPassword'), isFalse, reason: 'la contraseña temporal no debe estar en el doc principal');
      expect(emp.containsKey('_pendingReservation'), isFalse);
      expect(emp['hourlyRate'], 12.5);
      final cred = await emulatorGetDoc('employees/$uid/private/credentials');
      expect(cred, isNotNull);
      expect((restFields(cred!)['tempPassword'] as String).length, greaterThanOrEqualTo(8));
      // Email de bienvenida encolado en la colección mail (extensión SendGrid).
      final mails = await emulatorRunQuery({
        'from': [{'collectionId': 'mail'}],
      });
      final welcome = mails.map(restFields).where((m) => (m['to'] as List).contains(_newEmail));
      expect(welcome, isNotEmpty, reason: 'debe encolarse el correo de bienvenida');
    });

    testWidgets('EMP-005 el contador de plazas refleja la ocupación (4/5)', (tester) async {
      await launchApp(tester);
      await tapNav(tester, 'Empleados');
      await waitFor(tester, find.text('Lista de empleados'));
      await pumpFor(tester, const Duration(seconds: 2));
      expect(find.text('4/5'), findsOneWidget, reason: 'Ana, Luis, Marta y Nuevo QA ocupan plaza; el borrado no');
      await logoutCompany(tester);
    });

    testWidgets('EMP-006 farmacia gratuita con la plaza ocupada → modal de límite, no abre el formulario', (tester) async {
      await launchApp(tester);
      await loginAsCompany(tester, email: Seed.companyFreeEmail);
      await waitFor(tester, find.text('Trabajando'), timeout: const Duration(seconds: 40));
      await tapNav(tester, 'Empleados');
      await waitFor(tester, find.text('Lista de empleados'));
      await waitFor(tester, find.text('1/1'), timeout: const Duration(seconds: 20));
      await tester.tap(find.byType(FloatingActionButton));
      await waitFor(tester, find.text('¡Ups!'));
      expect(find.textContaining('límite de 1 empleado gratuito'), findsOneWidget);
      expect(find.text('Nuevo empleado'), findsNothing);
      // Cierra la hoja.
      await tester.tapAt(const Offset(10, 10));
      await pumpFor(tester, const Duration(milliseconds: 500));
      await tapNav(tester, 'Inicio');
      await logoutCompany(tester);
    });

    testWidgets('EMP-007 el nuevo empleado entra con la contraseña temporal y debe asignar contraseña', (tester) async {
      await launchApp(tester);
      final docs = await emulatorRunQuery({
        'from': [{'collectionId': 'employees'}],
        'where': {'fieldFilter': {'field': {'fieldPath': 'email'}, 'op': 'EQUAL', 'value': {'stringValue': _newEmail}}},
      });
      final uid = (docs.single['name'] as String).split('/').last;
      final cred = restFields((await emulatorGetDoc('employees/$uid/private/credentials'))!);
      final temp = cred['tempPassword'] as String;
      await loginAsEmployee(tester, email: _newEmail, password: temp);
      await waitFor(tester, find.text('Asignar contraseña'), timeout: const Duration(seconds: 40));
      await tester.enterText(find.widgetWithText(TextField, 'Nueva contraseña'), Seed.password);
      await tester.enterText(find.widgetWithText(TextField, 'Confirmar nueva contraseña'), Seed.password);
      await tapText(tester, 'Guardar cambios');
      await waitFor(tester, find.text('¡Hola, Nuevo!'), timeout: const Duration(seconds: 40));
      final after = restFields((await emulatorGetDoc('employees/$uid'))!);
      expect(after['accountStatus'], 'active');
      expect(after['hasTempPassword'], false);
      expect(tester.takeException(), isNull);
    });
  });
}
