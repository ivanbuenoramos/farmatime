// Flujo real de fichaje (empleado) + reflejo en el dashboard de la farmacia,
// contra el Emulator Suite. Verifica también los datos escritos en Firestore
// (REST del emulador) y el log de auditoría inmutable.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/qa_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('CLOCK', () {
    testWidgets('CLOCK-001 empleado sin fichajes ve FICHAR ENTRADA y 0 turnos', (tester) async {
      await launchApp(tester);
      await loginAsEmployee(tester, email: Seed.empAnaEmail);
      await waitFor(tester, find.text('¡Hola, Ana!'), timeout: const Duration(seconds: 40));
      await waitFor(tester, find.text('FICHAR ENTRADA'), timeout: const Duration(seconds: 20));
      expect(find.text('FICHAR SALIDA'), findsNothing);
      expect(await clockRecordsOf('qa-emp-ana'), isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CLOCK-002 doble tap en FICHAR ENTRADA crea UN solo fichaje abierto con auditoría', (tester) async {
      await launchApp(tester);
      await waitFor(tester, find.text('FICHAR ENTRADA'));
      final btn = find.text('FICHAR ENTRADA');
      await tester.tap(btn);
      await tester.pump(const Duration(milliseconds: 20));
      if (btn.evaluate().isNotEmpty) {
        await tester.tap(btn, warnIfMissed: false);
      }
      await waitFor(tester, find.text('FICHAR SALIDA'), timeout: const Duration(seconds: 30));
      // Deja terminar escrituras best-effort (auditLog).
      await pumpFor(tester, const Duration(seconds: 2));

      final records = await clockRecordsOf('qa-emp-ana');
      expect(records.length, 1, reason: 'el doble tap no debe duplicar el fichaje');
      final rec = records.single;
      expect(rec['companyId'], 'qa-company-paid');
      expect(rec['employeeId'], 'qa-emp-ana');
      expect(rec['clockOut'], isNull);
      expect(rec['isEdited'], false);
      expect(rec['clockIn'], isA<DateTime>());
      // Ubicación: si el simulador/emulador la proporciona, debe ser la fijada
      // por el runner (Madrid). Si no, se registra sin ubicación (permitido).
      final lat = rec['clockInLat'];
      if (lat != null) {
        expect((lat as num).toDouble(), closeTo(40.4168, 0.05));
      }
      // Log de auditoría inmutable: 1 entrada "created" firmada por el empleado.
      final logs = await emulatorListDocs('clockRecords/${rec['id']}/auditLog');
      expect(logs.length, 1, reason: 'debe existir el registro de creación en auditLog');
      final log = restFields(logs.single);
      expect(log['action'], 'created');
      expect(log['actorUid'], 'qa-emp-ana');
      expect(log['entryId'], rec['id']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CLOCK-003 la farmacia ve 1 trabajando en el dashboard', (tester) async {
      await launchApp(tester);
      await logoutEmployee(tester);
      await loginAsCompany(tester);
      await waitFor(tester, find.text('Trabajando'), timeout: const Duration(seconds: 40));
      // Espera a que lleguen los streams.
      final end = DateTime.now().add(const Duration(seconds: 15));
      while (DateTime.now().isBefore(end) && dashboardMetricValue('Trabajando') != '1') {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(dashboardMetricValue('Trabajando'), '1',
          reason: 'Ana tiene un fichaje abierto; textos: ${visibleTexts()}');
      expect(tester.takeException(), isNull);
      await logoutCompany(tester);
    });

    testWidgets('CLOCK-004 el estado "fichado" persiste entre sesiones y FICHAR SALIDA cierra el turno', (tester) async {
      await launchApp(tester);
      await loginAsEmployee(tester, email: Seed.empAnaEmail);
      await waitFor(tester, find.text('FICHAR SALIDA'), timeout: const Duration(seconds: 40));
      await tapText(tester, 'FICHAR SALIDA');
      await waitFor(tester, find.text('FICHAR ENTRADA'), timeout: const Duration(seconds: 30));
      await pumpFor(tester, const Duration(seconds: 1));
      final records = await clockRecordsOf('qa-emp-ana');
      expect(records.length, 1);
      final rec = records.single;
      expect(rec['clockOut'], isA<DateTime>());
      expect((rec['clockOut'] as DateTime).isAfter(rec['clockIn'] as DateTime), isTrue);
      expect(rec['isEdited'], false, reason: 'la salida del propio empleado no es una edición');
      // Campos de origen intactos (los exige firestore.rules).
      expect(rec['employeeId'], 'qa-emp-ana');
      expect(rec['companyId'], 'qa-company-paid');
      expect(tester.takeException(), isNull);
    });

    testWidgets('CLOCK-005 segundo turno del día: 2 fichajes y contador "Turnos hoy" = 2', (tester) async {
      await launchApp(tester);
      await waitFor(tester, find.text('FICHAR ENTRADA'));
      await tapText(tester, 'FICHAR ENTRADA');
      await waitFor(tester, find.text('FICHAR SALIDA'), timeout: const Duration(seconds: 30));
      await tapText(tester, 'FICHAR SALIDA');
      await waitFor(tester, find.text('FICHAR ENTRADA'), timeout: const Duration(seconds: 30));
      await pumpFor(tester, const Duration(seconds: 1));
      final records = await clockRecordsOf('qa-emp-ana');
      expect(records.length, 2);
      expect(records.where((r) => r['clockOut'] == null), isEmpty, reason: 'no quedan fichajes abiertos');
      expect(find.text('Turnos hoy'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Pestaña Fichajes del empleado: lista los 2 de hoy sin excepciones.
      await tapNav(tester, 'Fichajes');
      await pumpFor(tester, const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
      await tapNav(tester, 'Mi día');
      await logoutEmployee(tester);
    });

    testWidgets('CLOCK-006 la farmacia ve 0 trabajando tras las salidas y la pestaña Fichajes carga', (tester) async {
      await launchApp(tester);
      await loginAsCompany(tester);
      await waitFor(tester, find.text('Trabajando'), timeout: const Duration(seconds: 40));
      final end = DateTime.now().add(const Duration(seconds: 15));
      while (DateTime.now().isBefore(end) && dashboardMetricValue('Trabajando') != '0') {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(dashboardMetricValue('Trabajando'), '0', reason: 'textos: ${visibleTexts()}');
      await tapNav(tester, 'Fichajes');
      await pumpFor(tester, const Duration(seconds: 4));
      expect(tester.takeException(), isNull);
      await tapNav(tester, 'Inicio');
      await logoutCompany(tester);
    });
  });
}
