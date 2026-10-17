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
  // Turnos de AYER que cruzan medianoche y siguen en curso hoy (nocturnos).
  Map<String, ExpectedShiftModel?> _expectedPrevMap = {};
  Map<String, ClockSnap> _clocks = {};
  // Día para el que están cargados el stream y los turnos esperados.
  DateTime? _boundDay;

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
  // Resumen / lista unificada para la cabecera del dashboard
  // ─────────────────────────────────────────────────────────────

  /// Nº de empleados activos (no eliminados).
  int get totalEmployees => brain.companyEmployees
      .where((e) => e.accountStatus != EmployeeAccountStatus.deleted)
      .length;

  int get workingCount => working.length;
  int get absentCount => absent.length;

  /// Todos los empleados (no eliminados) ordenados por nombre, cada uno con
  /// su [EmployeeRow] resuelta (estado de hoy). Para la lista de la cabecera.
  List<EmployeeRow> get allRows {
    final byStatus = <String, EmployeeRow>{
      for (final r in working) r.emp.uid: r,
      for (final r in absent) r.emp.uid: r,
      for (final r in off) r.emp.uid: r,
    };

    final employees = brain.companyEmployees
        .where((e) => e.accountStatus != EmployeeAccountStatus.deleted)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return employees
        .map((e) =>
            byStatus[e.uid] ??
            EmployeeRow(emp: e, status: TodayStatus.off))
        .toList();
  }

  // ─────────────────────────────────────────────────────────────
  // Internals
  // ─────────────────────────────────────────────────────────────

  void _startNowTick() {
    _nowTimer?.cancel();

    _nowTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      now.value = DateTime.now();
      if (_boundDay != null && _boundDay != _todayStart) {
        // Cambio de día con el dashboard abierto: el stream y los turnos
        // esperados eran los de ayer.
        await _reloadExpected();
        _bindClocksStream();
      }
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
    } else {
      // Sin empleados (aún) no hay nada que cargar: evita spinner infinito.
      isLoading.value = false;
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
      _expectedPrevMap = {};
      return;
    }

    errorText.value = null;

    final ids = employees.map((e) => e.uid).toList();
    final todayStart = _todayStart;

    Result<Map<String, ExpectedShiftModel?>>? res;
    Result<Map<String, ExpectedShiftModel?>>? resPrev;
    try {
      // Cargamos también AYER: un turno nocturno (p.ej. 22:00→06:00) sigue en
      // curso de madrugada y el de hoy no lo refleja.
      final results = await Future.wait([
        getExpectedShiftsForDayUseCase.call(
          companyId: companyId,
          employeeIds: ids,
          dayDate: todayStart,
        ),
        getExpectedShiftsForDayUseCase.call(
          companyId: companyId,
          employeeIds: ids,
          dayDate: todayStart.subtract(const Duration(days: 1)),
        ),
      ]);
      res = results[0];
      resPrev = results[1];
    } catch (_) {
      res = null;
    }

    if (res == null || !res.success) {
      _expectedMap = {};
      _expectedPrevMap = {};
      errorText.value = 'Error al cargar turnos esperados';
      return;
    }

    _expectedMap = res.data;
    // De ayer solo interesan los turnos que terminan ya en el día de hoy.
    _expectedPrevMap = {
      if (resPrev != null && resPrev.success)
        for (final e in resPrev.data.entries)
          if (e.value != null && e.value!.end.isAfter(todayStart)) e.key: e.value,
    };
  }

  void _bindClocksStream() {
    final companyId = brain.company.value?.id;
    if (companyId == null || companyId.isEmpty) return;

    _clocksSub?.cancel();
    _boundDay = _todayStart;

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
      // Si el turno nocturno de ayer sigue en curso, manda sobre el de hoy.
      final expPrev = _expectedPrevMap[emp.uid];
      final prevRunning = expPrev != null &&
          n.isBefore(expPrev.end.add(const Duration(minutes: 1)));
      final exp = prevRunning ? expPrev : _expectedMap[emp.uid];
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
    // start/end ya vienen como instantes absolutos coherentes: el repositorio
    // suma un día a `end` cuando el turno cruza medianoche (ver
    // _shiftFromDayEntry/_shiftFromRule), así que end SIEMPRE es posterior a
    // start. Comparamos en la misma referencia local que `now` para evitar
    // desfases de zona horaria; comparar dos DateTime da el mismo resultado en
    // cualquier zona, así que no convertimos a UTC.
    final n = now ?? DateTime.now();
    if (end.isBefore(start)) {
      // Defensa: si por un cambio futuro `end` no trajera el +1 día, lo
      // corregimos aquí en vez de caer en una rama que daría falsos positivos.
      end = end.add(const Duration(days: 1));
    }
    return !n.isBefore(start) &&
        n.isBefore(end.add(const Duration(minutes: 1)));
  }
}