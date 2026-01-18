// lib/presentation/pages/company/dashboard/company_dashboard_controller.dart
import 'dart:async';
import 'package:farmatime/domain/usecases/employee_schedule/get_expected_shift_usecase.dart';
import 'package:get/get.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/data/models/employee_shift_model.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/usecases/clock/stream_today_last_clocks_usecase.dart';

enum TodayStatus { working, absent, off }

class EmployeeRow {
  final EmployeeModel emp;
  final TodayStatus status;
  final DateTime? lastClockIn;
  final ExpectedShiftModel? expected;

  EmployeeRow({
    required this.emp,
    required this.status,
    this.lastClockIn,
    this.expected,
  });
}

class IncoherentAlert {
  final EmployeeModel emp;
  final String reason;
  final int deltaMinutes;
  final DateTime date;

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
    required this.streamTodayLastClocksUseCase,
    required this.getExpectedShiftsForDayUseCase,
  });

  final Brain brain = Get.find<Brain>();

  /// ✅ Fichajes en tiempo real (sin whereIn => soporta >10 empleados)
  final StreamTodayLastClocksUseCase streamTodayLastClocksUseCase;

  /// Turno esperado (fetch). No es real-time.
  final GetExpectedShiftsForDayUseCase getExpectedShiftsForDayUseCase;

  // Estado UI
  final isLoading = false.obs;
  final errorText = RxnString();

  // “tick” para que el UI se actualice en tiempo real (cada 30s)
  final Rx<DateTime> now = DateTime.now().obs;
  Timer? _nowTimer;

  // Secciones
  final working = <EmployeeRow>[].obs;
  final absent = <EmployeeRow>[].obs;
  final off = <EmployeeRow>[].obs;
  final incoherent = <IncoherentAlert>[].obs;

  // Config
  final Duration incoherentThreshold = const Duration(minutes: 30);

  // cache interno
  Map<String, ExpectedShiftModel?> _expectedMap = {};
  Map<String, ClockSnap> _clocks = {};

  StreamSubscription<Map<String, (DateTime?, bool)>>? _clocksSub;
  Worker? _employeesWorker;

  DateTime get _todayStart {
    final d = DateTime.now();
    return DateTime(d.year, d.month, d.day, 0, 0, 0);
  }

  DateTime get _todayEnd =>
      _todayStart.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

  @override
  void onInit() {
    super.onInit();
    _startNowTick();
    _initRealtime();
  }

  @override
  void onClose() {
    _clocksSub?.cancel();
    _employeesWorker?.dispose();
    _nowTimer?.cancel();
    super.onClose();
  }

  // ─────────────────────────────────────────────────────────────
  // Public helpers para la UI
  // ─────────────────────────────────────────────────────────────

  String relTimeFrom(DateTime dt) {
    final diff = now.value.difference(dt);
    if (diff.inHours >= 1) {
      final h = diff.inHours;
      final m = diff.inMinutes % 60;
      return 'Hace ${h}h ${m}m';
    }
    return 'Hace ${diff.inMinutes}m';
  }

  Future<void> refreshAll() async {
    await _reloadExpected();
    _recompute();
  }

  void redirectToComapnyProfile() {
    Get.toNamed(Routes.companyProfile);
  }

  // ─────────────────────────────────────────────────────────────
  // Internals
  // ─────────────────────────────────────────────────────────────

  void _startNowTick() {
    _nowTimer?.cancel();

    _nowTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      now.value = DateTime.now();
      _recompute();
    });
  }

  void _initRealtime() {
    isLoading.value = true;
    errorText.value = null;

    _employeesWorker = ever<List<EmployeeModel>>(brain.companyEmployees, (_) async {
      await _reloadExpected(); // fetch
      _bindClocksStream();     // realtime
      _recompute();
      isLoading.value = false;
    });

    if (brain.companyEmployees.isNotEmpty) {
      _reloadExpected().then((_) {
        _bindClocksStream();
        _recompute();
        isLoading.value = false;
      });
    }
  }

  Future<void> _reloadExpected() async {
    final companyId = brain.company.value?.id;
    if (companyId == null || companyId.isEmpty) return;

    final employees = brain.companyEmployees
        .where((e) => e.accountStatus != EmployeeAccountStatus.deleted)
        .toList();

    if (employees.isEmpty) {
      _expectedMap = {};
      return;
    }

    errorText.value = null;

    final Result<Map<String, ExpectedShiftModel?>> res =
        await getExpectedShiftsForDayUseCase.call(
      companyId: companyId,
      employeeIds: employees.map((e) => e.uid).toList(),
      dayDate: _todayStart,
    );

    if (!res.success) {
      _expectedMap = {};
      errorText.value = 'Error al cargar turnos esperados';
      return;
    }

    _expectedMap = res.data;
  }

  void _bindClocksStream() {
    final companyId = brain.company.value?.id;
    if (companyId == null || companyId.isEmpty) return;

    _clocksSub?.cancel();

    _clocksSub = streamTodayLastClocksUseCase(
      companyId,
      _todayStart,
      _todayEnd,
    ).listen((raw) {
      _clocks = {
        for (final e in raw.entries)
          e.key: (isActive: e.value.$2, lastClockIn: e.value.$1),
      };
      _recompute();
    }, onError: (e) {
      errorText.value = 'Error al escuchar fichajes: $e';
    });
  }

  void _recompute() {
    final employees = brain.companyEmployees
        .where((e) => e.accountStatus != EmployeeAccountStatus.deleted)
        .toList();

    working.clear();
    absent.clear();
    off.clear();
    incoherent.clear();

    if (employees.isEmpty) return;

    final n = now.value;

    for (final emp in employees) {
      final exp = _expectedMap[emp.uid];
      final snap = _clocks[emp.uid];
      final isActive = snap?.isActive == true;
      final lastClockIn = snap?.lastClockIn;

      // Si tiene entrada abierta => working
      if (isActive && lastClockIn != null) {
        working.add(EmployeeRow(
          emp: emp,
          status: TodayStatus.working,
          lastClockIn: lastClockIn,
          expected: exp,
        ));
        continue;
      }

      // Sin turno esperado => off
      if (exp == null) {
        off.add(EmployeeRow(emp: emp, status: TodayStatus.off));
        continue;
      }

      final dentroDeTurno = _isNowWithinShift(exp.start, exp.end, now: n);

      if (dentroDeTurno) {
        absent.add(EmployeeRow(emp: emp, status: TodayStatus.absent, expected: exp));

        final delay = n.difference(exp.start);
        if (delay >= incoherentThreshold) {
          incoherent.add(IncoherentAlert(
            emp: emp,
            reason: 'Ausencia',
            deltaMinutes: delay.inMinutes,
            date: n,
          ));
        }
      } else {
        off.add(EmployeeRow(emp: emp, status: TodayStatus.off, expected: exp));
      }
    }

    // Orden consistente
    working.sort((a, b) => a.emp.name.compareTo(b.emp.name));
    absent.sort((a, b) => a.emp.name.compareTo(b.emp.name));
    off.sort((a, b) => a.emp.name.compareTo(b.emp.name));
  }

  bool _isNowWithinShift(DateTime start, DateTime end, {DateTime? now}) {
    final n = (now ?? DateTime.now()).toUtc();
    final s = start.toUtc();
    final e = end.toUtc();

    if (!e.isBefore(s)) {
      return (n.isAtSameMomentAs(s) || n.isAfter(s)) &&
          n.isBefore(e.add(const Duration(minutes: 1)));
    } else {
      return n.isAtSameMomentAs(s) ||
          n.isAfter(s) ||
          n.isBefore(e.add(const Duration(minutes: 1)));
    }
  }
}