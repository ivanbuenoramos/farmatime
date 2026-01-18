// lib/presentation/pages/company/employee_detail/employee_detail_controller.dart
import 'dart:async';

import 'package:collection/collection.dart';
import 'package:get/get.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/core/utils/leave_simple_utils.dart';

import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/data/models/employee_shift_model.dart';

// Fichajes
import 'package:farmatime/domain/usecases/clock/get_entries_by_employee_usecase.dart';

// Horario (mensual)
import 'package:farmatime/data/models/schedule/day_entry.dart';
import 'package:farmatime/data/models/schedule/recurring_shift_rule.dart';
import 'package:farmatime/domain/usecases/employee_schedule/stream_employee_month_schedule_usecase.dart';
import 'package:farmatime/domain/usecases/employee_schedule/stream_recurring_rules_usecase.dart';

class EmployeeDetailController extends GetxController {
  final GetEntriesByEmployeeUseCase getEntriesByEmployeeUseCase;

  // ✅ Streams nuevo
  final StreamEmployeeMonthScheduleUseCase streamMonthScheduleUseCase;
  final StreamRecurringRulesUseCase streamRecurringRulesUseCase;

  EmployeeDetailController({
    required this.getEntriesByEmployeeUseCase,
    required this.streamMonthScheduleUseCase,
    required this.streamRecurringRulesUseCase,
  });

  final Brain brain = Get.find<Brain>();

  // ──────────────────────────────────────────────
  // Estado general
  // ──────────────────────────────────────────────
  final balances = Rx<SimpleLeaveBalances?>(null);
  final Rx<EmployeeModel?> employee = Rx<EmployeeModel?>(null);

  // ──────────────────────────────────────────────
  // FICHAJES (tu estado)
  // ──────────────────────────────────────────────
  final groupedClockIns = <DateTime, List<_ClockInOutDisplay>>{}.obs;
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

  String get _companyId => brain.company.value!.id;
  String get _employeeId => employee.value!.uid;

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
      Get.snackbar('Error', 'No employee data provided');
    }
  }

  @override
  void onClose() {
    _monthSub?.cancel();
    _rulesSub?.cancel();
    super.onClose();
  }

  Future<void> _loadBalances() async {
    final emp = employee.value;
    if (emp == null) return;
    balances.value = computeSimpleBalances(employee: emp, hireDateOverride: emp.createdAt);
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
  }

  // ──────────────────────────────────────────────
  // FICHAJES (tu lógica existente)
  // ──────────────────────────────────────────────
  Future<void> fetch() async {
    final emp = employee.value;
    if (emp == null) {
      Get.snackbar('Error', 'Empleado no definido');
      return;
    }

    final result = await getEntriesByEmployeeUseCase.call(emp.uid);
    if (!result.success) {
      Get.snackbar('Error', 'No se pudieron cargar los registros de entrada');
      return;
    }

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

  // ──────────────────────────────────────────────
  // Navegación a edición de horario
  // ──────────────────────────────────────────────
  Future<void> redirectToEmployeeSchedule() async {
    final emp = employee.value;
    if (emp == null) {
      Get.snackbar('Error', 'Empleado no definido');
      return;
    }

    final res = await Get.toNamed(
      Routes.companyEmployeeSchedule,
      arguments: {'employeeId': emp.uid},
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