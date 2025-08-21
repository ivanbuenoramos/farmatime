// lib/presentation/pages/company/dashboard/company_dashboard_controller.dart
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/data/models/employee_shift_model.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/usecases/employee_schedule/get_expected_shift_usecase.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/domain/usecases/employee/get_employees_by_company_id_usecase.dart';
import 'package:farmatime/domain/usecases/clock/get_today_last_clocks_usecase.dart';


enum TodayStatus { working, absent, off }

class EmployeeRow {
  final EmployeeModel emp;
  final TodayStatus status;
  final DateTime? lastClockIn;               // si está trabajando
  final ExpectedShiftModel? expected;        // null si no trabaja hoy

  EmployeeRow({
    required this.emp,
    required this.status,
    this.lastClockIn,
    this.expected,
  });
}

class IncoherentAlert {
  final EmployeeModel emp;
  final String reason;    // "Ausencia", "Retraso", etc.
  final int deltaMinutes; // desviación
  final DateTime date;    // hoy

  IncoherentAlert({
    required this.emp,
    required this.reason,
    required this.deltaMinutes,
    required this.date,
  });
}

class CompanyDashboardController extends GetxController {
  CompanyDashboardController({
    required this.getEmployeesByCompany,
    required this.getTodayLastClocks,
    required this.getExpectedShiftsToday,
  });

  // Use cases
  final GetEmployeesByCompanyIdUseCase getEmployeesByCompany;
  final GetTodayLastClocksUseCase getTodayLastClocks;
  final GetExpectedShiftUseCase getExpectedShiftsToday;

  final Brain brain = Get.find<Brain>();

  // Estado UI
  final isLoading = false.obs;
  final errorText = RxnString();

  // Secciones (para la UI)
  final working = <EmployeeRow>[].obs;
  final absent  = <EmployeeRow>[].obs;
  final off     = <EmployeeRow>[].obs;

  final incoherent = <IncoherentAlert>[].obs;

  // Config
  final Duration incoherentThreshold = const Duration(minutes: 30);

  DateTime get _todayStart {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _todayEnd =>
      _todayStart.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

  String get _todayKey => DateFormat('yyyy-MM-dd').format(_todayStart);

  @override
  void onInit() {
    super.onInit();
    _loadAll();
  }

  Future<void> refreshAll() => _loadAll();

  Future<void> _loadAll() async {
    isLoading.value = true;
    errorText.value = null;

    try {

      // 1) Empleados activos de la empresa (EmployeeModel)
      final Result<List<EmployeeModel>> employeesResult = await getEmployeesByCompany.call(brain.company.value!.id);

      if (!employeesResult.success) {
        errorText.value = 'Error al cargar empleados: ${employeesResult.errorCode}';
        return;
      }

      final List<EmployeeModel> employees = employeesResult.data;

      // 2) Turno esperado de HOY por empleado (override + reglas)
      final Map<String, ExpectedShiftModel?> expectedMap =
          await getExpectedShiftsToday.call(
            companyId: brain.company.value!.id,
            employeeIds: employees.map((e) => e.uid).toList(),
            dayDate: _todayStart,
          );

      // 3) Último fichaje de HOY + si está activo
      final Map<String, (DateTime?, bool)> clocks =
          await getTodayLastClocks(brain.company.value!.id, _todayStart, _todayEnd);

      // 4) Clasificación
      working.clear();
      absent.clear();
      off.clear();
      incoherent.clear();

      for (final emp in employees) {
        final ExpectedShiftModel? exp = expectedMap[emp.uid];
        final lastForEmp = clocks[emp.uid];

        if (exp == null) {
          // No debe trabajar hoy
          off.add(EmployeeRow(emp: emp, status: TodayStatus.off));
          continue;
        }

        final bool isActive = lastForEmp?.$2 == true;
        final DateTime? lastClockIn = lastForEmp?.$1;

        if (isActive && lastClockIn != null) {
          // Trabajando (marcaje abierto)
          working.add(EmployeeRow(
            emp: emp,
            status: TodayStatus.working,
            lastClockIn: lastClockIn,
            expected: exp,
          ));
        } else {
          // No activo. ¿Debería estar?
          final now = DateTime.now();
          final bool dentroDeTurno = now.isAfter(exp.start) && now.isBefore(exp.end.add(const Duration(minutes: 1)));

          if (dentroDeTurno) {
            final delay = now.difference(exp.start);
            if (delay >= incoherentThreshold) {
              // Ausencia + incoherencia (>30 min sin fichar desde el inicio del turno)
              absent.add(EmployeeRow(emp: emp, status: TodayStatus.absent, expected: exp));
              incoherent.add(IncoherentAlert(
                emp: emp,
                reason: 'Ausencia',
                deltaMinutes: delay.inMinutes,
                date: now,
              ));
            } else {
              // Aún dentro del margen de 30'
              absent.add(EmployeeRow(emp: emp, status: TodayStatus.absent, expected: exp));
            }
          } else {
            // Fuera del tramo horario de hoy
            off.add(EmployeeRow(emp: emp, status: TodayStatus.off, expected: exp));
          }
        }
      }
    } catch (e) {
      errorText.value = 'Error al cargar el dashboard: $e';
    } finally {
      isLoading.value = false;
    }
  }

  // ─────────────── Helpers UI ───────────────
  String relTimeFrom(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inHours >= 1) {
      final h = diff.inHours, m = diff.inMinutes % 60;
      return 'Hace ${h}h ${m}m';
    }
    return 'Hace ${diff.inMinutes}m';
  }
}
