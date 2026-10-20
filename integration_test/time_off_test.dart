// Ausencias (vacaciones / asuntos propios) contra el emulador: el empleado
// solicita días, cancela una solicitud, la farmacia aprueba la otra y el
// calendario mensual (employee_schedule_months) queda marcado.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/qa_harness.dart';

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Selecciona [target] en un showDatePicker ya abierto y confirma.
Future<void> _pickDayInDialog(WidgetTester tester, DateTime target) async {
  await waitFor(tester, find.byType(DatePickerDialog));
  final now = DateTime.now();
  var monthsAhead = (target.year - now.year) * 12 + (target.month - now.month);
  while (monthsAhead > 0) {
    await tester.tap(find.byTooltip('Mes siguiente'));
    await pumpFor(tester, const Duration(milliseconds: 400));
    monthsAhead--;
  }
  final dayCell = find.descendant(of: find.byType(DatePickerDialog), matching: find.text('${target.day}'));
  await waitFor(tester, dayCell);
  await tester.tap(dayCell.last);
  await pumpFor(tester, const Duration(milliseconds: 300));
  await tapText(tester, 'Aceptar');
  await waitForGone(tester, find.byType(DatePickerDialog));
}

Future<void> _openRequestLeave(WidgetTester tester) async {
  await tapNav(tester, 'Calendario');
  await waitFor(tester, find.text('Mi calendario'));
  await tester.tap(find.byIcon(Icons.event_available_rounded).hitTestable().first);
  await waitFor(tester, find.text('Solicitar vacaciones y permisos'));
}

Future<List<Map<String, dynamic>>> _requestsOf(String uid) async {
  final docs = await emulatorRunQuery({
    'from': [{'collectionId': 'time_off_requests'}],
    'where': {'fieldFilter': {'field': {'fieldPath': 'employeeId'}, 'op': 'EQUAL', 'value': {'stringValue': uid}}},
  });
  return docs.map((d) => {...restFields(d), '_id': (d['name'] as String).split('/').last}).toList();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final vacationDay = DateTime.now().add(const Duration(days: 10));
  final personalDay = DateTime.now().add(const Duration(days: 12));

  group('TIME-OFF', () {
    testWidgets('TO-001 sin fechas el botón Enviar está deshabilitado', (tester) async {
      await launchApp(tester);
      await loginAsEmployee(tester, email: Seed.empAnaEmail);
      await waitFor(tester, find.text('¡Hola, Ana!'), timeout: const Duration(seconds: 40));
      await _openRequestLeave(tester);
      final btn = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Enviar solicitud'));
      expect(btn.onPressed, isNull);
      expect(find.text('Tus saldos'), findsOneWidget);
    });

    testWidgets('TO-002 solicitud de vacaciones (día suelto) → Pendiente y persistida con status requested', (tester) async {
      await launchApp(tester);
      await _openRequestLeave(tester);
      await tapText(tester, 'Días sueltos');
      await tapText(tester, 'Añadir día');
      await _pickDayInDialog(tester, vacationDay);
      await tester.enterText(find.widgetWithText(TextField, 'Añade información útil para tu responsable…'), 'Nota QA vacaciones');
      await tapText(tester, 'Enviar solicitud');
      await waitForToast(tester, 'Solicitud enviada', timeout: const Duration(seconds: 20));
      await waitFor(tester, find.text('Pendiente'), timeout: const Duration(seconds: 20));
      final reqs = await _requestsOf('qa-emp-ana');
      expect(reqs.length, 1);
      expect(reqs.single['status'], 'requested');
      expect(reqs.single['type'], 'vacation');
      expect(reqs.single['companyId'], 'qa-company-paid');
      expect((reqs.single['dates'] as List).cast<String>(), [_ymd(vacationDay)]);
      expect(reqs.single['note'], 'Nota QA vacaciones');
      expect(tester.takeException(), isNull);
    });

    testWidgets('TO-003 segunda solicitud (asuntos propios) y cancelación con confirmación → cancelled', (tester) async {
      await launchApp(tester);
      await _openRequestLeave(tester);
      await tapText(tester, 'Asuntos propios');
      await tapText(tester, 'Días sueltos');
      await tapText(tester, 'Añadir día');
      await _pickDayInDialog(tester, personalDay);
      await tapText(tester, 'Enviar solicitud');
      await waitForToast(tester, 'Solicitud enviada', timeout: const Duration(seconds: 20));
      await pumpFor(tester, const Duration(seconds: 2));
      var reqs = await _requestsOf('qa-emp-ana');
      expect(reqs.length, 2);
      // Cancela la de asuntos propios desde "Mis solicitudes".
      final cancelBtn = find.widgetWithText(OutlinedButton, 'Cancelar solicitud');
      final anyCancel = cancelBtn.evaluate().isNotEmpty ? cancelBtn : find.text('Cancelar solicitud');
      await waitFor(tester, anyCancel);
      // La lista muestra la más reciente primero: la de asuntos propios.
      await tester.ensureVisible(anyCancel.first);
      await tester.tap(anyCancel.first);
      await waitFor(tester, find.text('¿Seguro que quieres cancelar esta solicitud? Esta acción no se puede deshacer.'));
      await tester.tap(find.widgetWithText(FilledButton, 'Cancelar solicitud'));
      await waitForToast(tester, 'Solicitud cancelada', timeout: const Duration(seconds: 20));
      await pumpFor(tester, const Duration(seconds: 2));
      reqs = await _requestsOf('qa-emp-ana');
      final cancelled = reqs.where((r) => r['status'] == 'cancelled').toList();
      final requested = reqs.where((r) => r['status'] == 'requested').toList();
      expect(cancelled.length, 1);
      expect(requested.length, 1);
      expect(tester.takeException(), isNull);
      await goBack(tester);
      await waitFor(tester, find.text('Mi calendario'));
      await tapNav(tester, 'Mi día');
      await logoutEmployee(tester);
    });

    testWidgets('TO-004 la farmacia ve 1 pendiente y la aprueba → approved + calendario marcado', (tester) async {
      await launchApp(tester);
      await loginAsCompany(tester);
      await waitFor(tester, find.text('Trabajando'), timeout: const Duration(seconds: 40));
      await tapNav(tester, 'Empleados');
      await waitFor(tester, find.text('Solicitudes de ausencia'));
      await waitFor(tester, find.text('1 pendiente de revisar'), timeout: const Duration(seconds: 20));
      await tapText(tester, 'Solicitudes de ausencia');
      await waitFor(tester, find.text('Pendientes (1)'), timeout: const Duration(seconds: 20));
      await waitFor(tester, find.text(Seed.empAnaName), timeout: const Duration(seconds: 20));
      await tapText(tester, Seed.empAnaName);
      await waitFor(tester, find.text('Aprobar'), timeout: const Duration(seconds: 20));
      await tapText(tester, 'Aprobar');
      await waitForToast(tester, 'Solicitud aprobada', timeout: const Duration(seconds: 20));
      await pumpFor(tester, const Duration(seconds: 2));

      final reqs = await _requestsOf('qa-emp-ana');
      final approved = reqs.where((r) => r['status'] == 'approved').toList();
      expect(approved.length, 1);
      expect(approved.single['decidedBy'], 'qa-company-paid');
      // Calendario mensual del empleado: la fecha aprobada queda marcada.
      final month = '${vacationDay.year}-${vacationDay.month.toString().padLeft(2, '0')}';
      final cal = await emulatorGetDoc('employee_schedule_months/qa-company-paid__qa-emp-ana__$month');
      expect(cal, isNotNull, reason: 'la aprobación debe escribir el override mensual');
      final entries = (restFields(cal!)['entries'] ?? {}) as Map;
      expect(entries.containsKey(_ymd(vacationDay)), isTrue, reason: 'entries: $entries');
      expect(find.text('No hay solicitudes pendientes.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await goBack(tester);
      await waitFor(tester, find.text('Lista de empleados'));
      await tapNav(tester, 'Inicio');
      await logoutCompany(tester);
    });

    testWidgets('TO-005 el empleado ve la solicitud Aprobada y su saldo refleja el día asignado', (tester) async {
      await launchApp(tester);
      await loginAsEmployee(tester, email: Seed.empAnaEmail);
      await waitFor(tester, find.text('¡Hola, Ana!'), timeout: const Duration(seconds: 40));
      await _openRequestLeave(tester);
      await waitFor(tester, find.text('Aprobada'), timeout: const Duration(seconds: 20));
      expect(find.text('Cancelada'), findsOneWidget);
      expect(find.text('Asignados'), findsWidgets);
      expect(tester.takeException(), isNull);
      await goBack(tester);
      await waitFor(tester, find.text('Mi calendario'));
      await tapNav(tester, 'Mi día');
      await logoutEmployee(tester);
    });
  });
}
