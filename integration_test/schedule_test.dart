// Horarios: la farmacia asigna a Ana un turno de plantilla ("Mañana") para
// hoy desde el calendario del empleado, guarda, y el override mensual queda
// en Firestore; después Ana ve el turno en "Mi día".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/qa_harness.dart';

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Finder _calendarDay(int day) => find.descendant(
      of: find.byWidgetPredicate((w) => w.runtimeType.toString().startsWith('TableCalendar')),
      matching: find.text('$day'),
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final today = DateTime.now();

  group('SCHEDULE', () {
    testWidgets('SCH-001 asignar turno "Mañana" a hoy y guardar → override mensual en Firestore', (tester) async {
      await launchApp(tester);
      await loginAsCompany(tester);
      await waitFor(tester, find.text('Trabajando'), timeout: const Duration(seconds: 40));
      await tapNav(tester, 'Empleados');
      await waitFor(tester, find.text(Seed.empAnaName), timeout: const Duration(seconds: 20));
      await tapText(tester, Seed.empAnaName);
      await waitFor(tester, find.text('Perfil de empleado'), timeout: const Duration(seconds: 20));
      final editar = find.widgetWithText(TextButton, 'Editar');
      final editarAny = editar.evaluate().isNotEmpty ? editar : find.text('Editar');
      await tester.ensureVisible(editarAny.first);
      await tester.tap(editarAny.first);
      await waitFor(tester, find.text('Horario'), timeout: const Duration(seconds: 20));
      await pumpFor(tester, const Duration(seconds: 2));

      // Toca el día de hoy en el calendario → hoja de acciones del día.
      final dayCell = _calendarDay(today.day);
      await waitFor(tester, dayCell, timeout: const Duration(seconds: 20));
      await tester.tap(dayCell.first);
      await waitFor(tester, find.text('Turno laboral'), timeout: const Duration(seconds: 10));
      await tapText(tester, 'Turno laboral');
      await waitFor(tester, find.text('Elige un turno'), timeout: const Duration(seconds: 10));
      expect(find.text('Mañana'), findsWidgets, reason: 'las plantillas sembradas deben listarse');
      await tapText(tester, 'Mañana');
      await waitForGone(tester, find.text('Elige un turno'));
      await pumpFor(tester, const Duration(milliseconds: 500));

      await tapText(tester, 'Guardar');
      await waitForGone(tester, find.text('Guardando…'), timeout: const Duration(seconds: 30));
      await pumpFor(tester, const Duration(seconds: 2));
      expect(tester.takeException(), isNull);

      final month = '${today.year}-${today.month.toString().padLeft(2, '0')}';
      final doc = await emulatorGetDoc('employee_schedule_months/qa-company-paid__qa-emp-ana__$month');
      expect(doc, isNotNull, reason: 'debe existir el doc mensual de Ana');
      final entries = (restFields(doc!)['entries'] ?? {}) as Map;
      final entry = entries[_ymd(today)] as Map?;
      expect(entry, isNotNull, reason: 'entries: $entries');
      expect(entry!['type'], 'work');
      expect(entry['start'], '0900');
      expect(entry['end'], '1400');
    });

    testWidgets('SCH-002 volver atrás sin cambios no pide confirmación y la farmacia cierra sesión', (tester) async {
      await launchApp(tester);
      await tapNav(tester, 'Empleados');
      await waitFor(tester, find.text(Seed.empAnaName), timeout: const Duration(seconds: 20));
      await tapText(tester, Seed.empAnaName);
      await waitFor(tester, find.text('Perfil de empleado'), timeout: const Duration(seconds: 20));
      final editar = find.text('Editar');
      await tester.ensureVisible(editar.first);
      await tester.tap(editar.first);
      await waitFor(tester, find.text('Horario'), timeout: const Duration(seconds: 20));
      await pumpFor(tester, const Duration(seconds: 2));
      await goBack(tester);
      await pumpFor(tester, const Duration(seconds: 1));
      expect(find.text('Cambios sin guardar'), findsNothing);
      await waitFor(tester, find.text('Perfil de empleado'), timeout: const Duration(seconds: 10));
      await goBack(tester);
      await waitFor(tester, find.text('Lista de empleados'), timeout: const Duration(seconds: 10));
      await tapNav(tester, 'Inicio');
      await logoutCompany(tester);
    });

    testWidgets('SCH-003 Ana ve el turno de hoy (09:00–14:00) en Mi día', (tester) async {
      await launchApp(tester);
      await loginAsEmployee(tester, email: Seed.empAnaEmail);
      await waitFor(tester, find.text('¡Hola, Ana!'), timeout: const Duration(seconds: 40));
      await waitForAny(tester, [find.textContaining('09:00'), find.textContaining('9:00')],
          timeout: const Duration(seconds: 30));
      expect(find.textContaining('14:00'), findsWidgets);
      expect(tester.takeException(), isNull);
      await logoutEmployee(tester);
    });
  });
}
