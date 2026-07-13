// lib/presentation/pages/company/employee_detail/employee_detail_controller.dart
import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:farmatime/presentation/widgets/time_off/time_off_manage_sheet.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/core/services/toast_service.dart';
import 'package:farmatime/core/utils/leave_simple_utils.dart';

import 'package:farmatime/data/models/employee_model.dart';

// Fichajes
import 'package:farmatime/data/models/clock_in_out_model.dart';
import 'package:farmatime/domain/usecases/clock/get_entries_by_employee_usecase.dart';

// Horario (mensual)
import 'package:farmatime/data/models/schedule/day_entry.dart';
import 'package:farmatime/data/models/schedule/recurring_shift_rule.dart';
import 'package:farmatime/domain/usecases/employee_schedule/stream_employee_month_schedule_usecase.dart';
import 'package:farmatime/domain/usecases/employee_schedule/stream_recurring_rules_usecase.dart';

// Solicitudes de ausencia
import 'package:farmatime/data/models/schedule/time_off_model.dart';
import 'package:farmatime/domain/usecases/time_off/stream_time_off_by_employee_usecase.dart';
import 'package:farmatime/domain/usecases/time_off/decide_time_off_usecase.dart';
import 'package:farmatime/domain/usecases/time_off/find_time_off_overlaps_usecase.dart';

class EmployeeDetailController extends GetxController {
  final GetEntriesByEmployeeUseCase getEntriesByEmployeeUseCase;

  // ✅ Streams nuevo
  final StreamEmployeeMonthScheduleUseCase streamMonthScheduleUseCase;
  final StreamRecurringRulesUseCase streamRecurringRulesUseCase;

  // Solicitudes de ausencia
  final StreamTimeOffByEmployeeUseCase streamTimeOffByEmployeeUseCase;
  final DecideTimeOffUseCase decideTimeOffUseCase;
  final FindTimeOffOverlapsUseCase findTimeOffOverlapsUseCase;

  EmployeeDetailController({
    required this.getEntriesByEmployeeUseCase,
    required this.streamMonthScheduleUseCase,
    required this.streamRecurringRulesUseCase,
    required this.streamTimeOffByEmployeeUseCase,
    required this.decideTimeOffUseCase,
    required this.findTimeOffOverlapsUseCase,
  });

  final Brain brain = Get.find<Brain>();

  // ──────────────────────────────────────────────
  // SOLICITUDES DE AUSENCIA (real-time)
  // ──────────────────────────────────────────────
  final RxList<TimeOffModel> timeOffRequests = <TimeOffModel>[].obs;
  StreamSubscription<List<TimeOffModel>>? _timeOffSub;

  /// uid de la empresa que toma las decisiones.
  String get decidedBy => brain.company.value?.id ?? '';

  // ──────────────────────────────────────────────
  // Estado general
  // ──────────────────────────────────────────────
  final balances = Rx<SimpleLeaveBalances?>(null);
  final Rx<EmployeeModel?> employee = Rx<EmployeeModel?>(null);

  // ──────────────────────────────────────────────
  // FICHAJES (tu estado)
  // ──────────────────────────────────────────────
  final groupedClockIns = <DateTime, List<_ClockInOutDisplay>>{}.obs;

  /// Fichajes en crudo (turnos entrada/salida) para poder comparar previsto
  /// vs. realizado en el modal de detalle de día.
  final List<ClockInOutModel> _allEntries = [];

  final selectedMonth = DateTime(DateTime.now().year, DateTime.now().month).obs;

  void prevMonth() => selectedMonth.value =
      DateTime(selectedMonth.value.year, selectedMonth.value.month - 1);

  void nextMonth() => selectedMonth.value =
      DateTime(selectedMonth.value.year, selectedMonth.value.month + 1);

  // ──────────────────────────────────────────────
  // HORARIO (mensual, real-time)
  // ──────────────────────────────────────────────
  final Rx<DateTime> calendarFocusedDay = DateTime.now().obs;

  /// Overrides SOLO del mes visible (lo que consume el widget)
  final RxMap<DateTime, DayEntry> scheduleOverrides = <DateTime, DayEntry>{}.obs;

  /// Cache por mes: 'yyyy-MM' -> (dateOnly -> DayEntry)
  final Map<String, Map<DateTime, DayEntry>> _overridesCache = {};

  /// Reglas recurrentes (real-time)
  final RxList<RecurringShiftRule> scheduleRules = <RecurringShiftRule>[].obs;

  final RxBool isLoadingSchedule = false.obs;

  StreamSubscription<Map<String, DayEntry>>? _monthSub;
  StreamSubscription<List<RecurringShiftRule>>? _rulesSub;

  String get _companyId => brain.company.value?.id ?? '';
  String get _employeeId => employee.value?.uid ?? '';

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  @override
  void onInit() {
    super.onInit();

    final arg = Get.arguments;
    if (arg is EmployeeModel) {
      initWithEmployee(arg);
      _loadBalances();
    } else {
      ToastService().show(title: 'Error', message: 'No employee data provided', type: ToastType.error);
    }
  }

  @override
  void onClose() {
    _monthSub?.cancel();
    _rulesSub?.cancel();
    _timeOffSub?.cancel();
    super.onClose();
  }

  /// Solicitudes que requieren acción de la empresa (recién solicitadas).
  int get pendingTimeOffCount =>
      timeOffRequests.where((r) => r.awaitingCompany).length;

  void _bindTimeOffStream() {
    _timeOffSub?.cancel();
    if (_companyId.isEmpty || _employeeId.isEmpty) return;
    _timeOffSub = streamTimeOffByEmployeeUseCase
        .call(companyId: _companyId, employeeId: _employeeId)
        .listen((list) {
      timeOffRequests.assignAll(list);
      _loadBalances(); // recalcula descontando los días aprobados
    }, onError: (e) {
      // No rompas la UI por las solicitudes
      print('streamTimeOffByEmployee error: $e');
    });
  }

  Future<void> _loadBalances() async {
    final emp = employee.value;
    if (emp == null) return;
    balances.value = computeBalancesWithRequests(
      employee: emp,
      requests: timeOffRequests,
      hireDateOverride: emp.createdAt,
    );
  }

  void initWithEmployee(EmployeeModel e) {
    employee.value = e;

    // Fichajes
    fetch();

    // Horario: mes actual (lo pones al 15 para que TableCalendar cargue bien)
    calendarFocusedDay.value = DateTime(DateTime.now().year, DateTime.now().month, 15);

    // ✅ Real-time: reglas + mes visible
    _bindRulesStream();
    _bindMonthStream(calendarFocusedDay.value);

    // ✅ Real-time: solicitudes de ausencia
    _bindTimeOffStream();
  }

  /// Abre la hoja de gestión de una solicitud (aprobar/rechazar/proponer).
  Future<void> manageTimeOff(BuildContext context, TimeOffModel request) async {
    await TimeOffManageSheet.show(
      context,
      request: request,
      employeeName: employee.value?.name ?? 'Empleado',
      decideUseCase: decideTimeOffUseCase,
      overlapsUseCase: findTimeOffOverlapsUseCase,
      decidedBy: decidedBy,
    );
    // El stream refresca la lista automáticamente; nada más que hacer.
  }

  // ──────────────────────────────────────────────
  // FICHAJES (tu lógica existente)
  // ──────────────────────────────────────────────
  Future<void> fetch() async {
    final emp = employee.value;
    if (emp == null) {
      ToastService().show(title: 'Error', message: 'Empleado no definido', type: ToastType.error);
      return;
    }

    final result = await getEntriesByEmployeeUseCase.call(emp.uid);
    if (!result.success) {
      ToastService().show(title: 'Error', message: 'No se pudieron cargar los registros de entrada', type: ToastType.error);
      return;
    }

    // Guardamos los fichajes en crudo para el modal de detalle de día.
    _allEntries
      ..clear()
      ..addAll(result.data);

    final allItems = <_ClockInOutDisplay>[];
    for (final m in result.data) {
      allItems.add(_ClockInOutDisplay(time: m.clockIn, type: ClockInOutType.entry));
      if (m.clockOut != null) {
        allItems.add(_ClockInOutDisplay(time: m.clockOut!, type: ClockInOutType.exit));
      }
    }
    allItems.sort((a, b) => b.time.compareTo(a.time));

    final groups = groupBy(allItems, (e) => DateTime(e.time.year, e.time.month, e.time.day));
    final entriesList = groups.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    final last5 = Map<DateTime, List<_ClockInOutDisplay>>.fromEntries(entriesList.take(5));

    groupedClockIns.value = last5;
  }

  /// Fichajes (turnos) registrados en un día concreto, ordenados por hora.
  List<ClockInOutModel> clockRecordsForDay(DateTime day) {
    final d = _dateOnly(day);
    final list = _allEntries
        .where((e) =>
            e.clockIn.year == d.year &&
            e.clockIn.month == d.month &&
            e.clockIn.day == d.day)
        .toList()
      ..sort((a, b) => a.clockIn.compareTo(b.clockIn));
    return list;
  }

  /// Minutos realmente trabajados ese día según fichajes (turnos abiertos
  /// cuentan hasta ahora).
  int workedMinutesForDay(DateTime day) {
    final now = DateTime.now();
    return clockRecordsForDay(day).fold<int>(0, (prev, r) {
      final end = r.clockOut ?? now;
      return prev + end.difference(r.clockIn).inMinutes.clamp(0, 24 * 60);
    });
  }

  // ──────────────────────────────────────────────
  // Navegación a edición de horario
  // ──────────────────────────────────────────────
  Future<void> redirectToEmployeeSchedule() async {
    final emp = employee.value;
    if (emp == null) {
      ToastService().show(title: 'Error', message: 'Empleado no definido', type: ToastType.error);
      return;
    }

    final res = await Get.toNamed(
      Routes.companyEmployeeSchedule,
      arguments: {'employeeId': emp.uid, 'employeeName': emp.name},
    );

    // Con stream NO es necesario, pero si devuelves result y quieres forzar:
    if (res is Map && res['savedMonths'] is List) {
      _bindMonthStream(calendarFocusedDay.value);
    }
  }

  // ──────────────────────────────────────────────
  // HORARIO real-time
  // ──────────────────────────────────────────────
  void _bindRulesStream() {
    _rulesSub?.cancel();

    _rulesSub = streamRecurringRulesUseCase(
      companyId: _companyId,
      employeeId: _employeeId,
    ).listen((list) {
      scheduleRules.assignAll(list);
    }, onError: (e) {
      // No rompas UI por reglas
      print('streamRecurringRules error: $e');
    });
  }

  void _bindMonthStream(DateTime focused) {
    _monthSub?.cancel();

    isLoadingSchedule.value = true;

    final mk = _monthKey(focused);

    // pinta instantáneo si ya tienes cache
    if (_overridesCache.containsKey(mk)) {
      scheduleOverrides.assignAll(_overridesCache[mk] ?? {});
      isLoadingSchedule.value = false;
    } else {
      scheduleOverrides.clear();
    }

    _monthSub = streamMonthScheduleUseCase(
      companyId: _companyId,
      employeeId: _employeeId,
      year: focused.year,
      month: focused.month,
    ).listen((rawByDateKey) {
      // rawByDateKey: { 'yyyy-MM-dd': DayEntry }
      final map = <DateTime, DayEntry>{};

      rawByDateKey.forEach((k, v) {
        final d = DateTime.parse(k);
        map[_dateOnly(d)] = v;
      });

      _overridesCache[mk] = map;

      // si sigue siendo el mes visible, pinta
      if (_monthKey(calendarFocusedDay.value) == mk) {
        scheduleOverrides.assignAll(map);
      }

      isLoadingSchedule.value = false;
    }, onError: (e) {
      isLoadingSchedule.value = false;
      print('streamMonthSchedule error: $e');
    });
  }

  // Cambio de página del calendario: engancha stream del mes visible
  Future<void> onCalendarPageChanged(DateTime focused) async {
    calendarFocusedDay.value = focused;
    _bindMonthStream(focused);
  }

  // ──────────────────────────────────────────────
  // Helpers (si los usa tu UI de calendario)
  // ──────────────────────────────────────────────
  DayEntry? entryFor(DateTime day) {
    final d = _dateOnly(day);
    final mk = _monthKey(d);
    final map = _overridesCache[mk];
    return map?[d];
  }

  DayEntry? computedEntryFor(DateTime day) {
    final override = entryFor(day);
    if (override != null) return override;

    final r = scheduleRules.firstWhereOrNull((r) => r.matchesDate(day));
    if (r == null) return null;

    return DayEntry(type: DayType.work, start: r.startTime, end: r.endTime);
  }

  void reditectToUpsertEmployee(EmployeeModel? employee) {
    Get.toNamed(Routes.companyUpsertEmployee, arguments: employee);
  }

  void redirectToDeleteEmployee(EmployeeModel employee) {
    Get.toNamed(Routes.companyDeleteEmployee, arguments: employee);
  }
}

enum ClockInOutType { entry, exit }

class _ClockInOutDisplay {
  final DateTime time;
  final ClockInOutType type;

  _ClockInOutDisplay({required this.time, required this.type});
}