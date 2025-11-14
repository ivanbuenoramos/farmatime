import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/presentation/pages/company/employees/company_employees_controller.dart';
import 'package:farmatime/presentation/pages/company/subscription/subscription_controller.dart';
import 'package:get/get.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/data/models/employee_shift_model.dart';
import 'package:farmatime/domain/usecases/clock/get_today_last_clocks_usecase.dart';
import 'package:farmatime/domain/usecases/employee/get_employees_by_company_id_usecase.dart';
import 'package:farmatime/domain/usecases/employee_schedule/get_expected_shift_usecase.dart';



enum TodayStatus { working, absent, off }

class EmployeeRow {
  final EmployeeModel emp;
  final TodayStatus status;
  final DateTime? lastClockIn;        // si está trabajando
  final ExpectedShiftModel? expected; // null si no trabaja hoy

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

// Usamos nombres para evitar líos con $1/$2
typedef ClockSnap = ({bool isActive, DateTime? lastClockIn});

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

  final CompanyEmployeesController companyEmployeesController = Get.find<CompanyEmployeesController>();

  final Brain brain = Get.find<Brain>();

  // Estado UI
  final isLoading = false.obs;
  final errorText = RxnString();

  // Secciones
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
      // 1) Empleados activos de la empresa
      final Result<List<EmployeeModel>> employeesResult =
          await getEmployeesByCompany.call(brain.company.value!.id);

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

      // 3) Último fichaje de HOY + indicador de actividad
      //    El use case devuelve (DateTime? lastClockIn, bool isActive)
      //    isActive debe significar: "tiene entrada abierta (clockOut == null)".
      final Map<String, (DateTime?, bool)> rawClocks =
          await getTodayLastClocks(brain.company.value!.id, _todayStart, _todayEnd);

      // Normalizamos a record con nombres
      final Map<String, ClockSnap> clocks = {
        for (final e in rawClocks.entries)
          e.key: (isActive: e.value.$2, lastClockIn: e.value.$1)
      };

      // 4) Clasificación según tus reglas
      working.clear();
      absent.clear();
      off.clear();
      incoherent.clear();

      for (final emp in employees) {
        final exp = expectedMap[emp.uid];
        final snap = clocks[emp.uid];
        final isActive = snap?.isActive == true;
        final lastClockIn = snap?.lastClockIn;

        // 👇 nuevo: si está con entrada abierta, es Working aunque exp sea null
        if (isActive && lastClockIn != null) {
          working.add(EmployeeRow(
            emp: emp,
            status: TodayStatus.working,
            lastClockIn: lastClockIn,
            expected: exp,
          ));
          continue;
        }

        if (exp == null) {
          off.add(EmployeeRow(emp: emp, status: TodayStatus.off));
          continue;
        }

        final now = DateTime.now();
        final dentroDeTurno = _isNowWithinShift(exp.start, exp.end, now: now);

        if (dentroDeTurno) {
          absent.add(EmployeeRow(emp: emp, status: TodayStatus.absent, expected: exp));
          final delay = now.difference(exp.start);
          if (delay >= incoherentThreshold) {
            incoherent.add(IncoherentAlert(
              emp: emp,
              reason: 'Ausencia',
              deltaMinutes: delay.inMinutes,
              date: now,
            ));
          }
        } else {
          off.add(EmployeeRow(emp: emp, status: TodayStatus.off, expected: exp));
        }
}
      print(working.length);
      print(absent.length);
      print(off.length);
      print(incoherent.length);
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

  bool _isNowWithinShift(DateTime start, DateTime end, {DateTime? now}) {
    // Normaliza todo a UTC para evitar desfases TZ
    final n = (now ?? DateTime.now()).toUtc();
    final s = start.toUtc();
    final e = end.toUtc();

    if (!e.isBefore(s)) {
      // Turno normal mismo día: [start, end] (incluimos 1 min de margen)
      return (n.isAtSameMomentAs(s) || n.isAfter(s)) &&
            (n.isBefore(e.add(const Duration(minutes: 1))));
    } else {
      // Turno nocturno: start -> 23:59... y 00:00 -> end (día siguiente)
      // Dentro si: n >= start  (hoy)  OR  n <= end (mañana)
      return n.isAtSameMomentAs(s) || n.isAfter(s) || n.isBefore(e.add(const Duration(minutes: 1)));
    }
  }

  void redirectToComapnyProfile() {
    Get.toNamed(Routes.companyProfile);
  }
}
