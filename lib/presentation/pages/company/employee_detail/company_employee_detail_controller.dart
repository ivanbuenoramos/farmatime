import 'package:farmatime/core/utils/leave_simple_utils.dart';
import 'package:get/get.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:collection/collection.dart';
import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/domain/usecases/clock/get_entries_by_employee_usecase.dart';

// ▼ imports NUEVOS (horario)
import 'package:farmatime/data/models/schedule/day_entry.dart';
import 'package:farmatime/data/models/schedule/recurring_shift_rule.dart';
import 'package:farmatime/domain/usecases/employee_schedule/get_employee_year_schedule_usecase.dart';
import 'package:farmatime/domain/usecases/employee_schedule/list_recurring_rules_usecase.dart';

class EmployeeDetailController extends GetxController {

  final GetEntriesByEmployeeUseCase getEntriesByEmployeeUseCase;

  // ▼ usecases NUEVOS
  final GetEmployeeYearScheduleUseCase getYearScheduleUseCase;
  final ListRecurringRulesUseCase listRecurringRulesUseCase;

  EmployeeDetailController({
    required this.getEntriesByEmployeeUseCase,
    required this.getYearScheduleUseCase,
    required this.listRecurringRulesUseCase,
  });

  final Brain brain = Get.find<Brain>();

  final balances = Rx<SimpleLeaveBalances?>(null);

  final Rx<EmployeeModel?> employee = Rx<EmployeeModel?>(null);
  final groupedClockIns = <DateTime, List<_ClockInOutDisplay>>{}.obs;

  // ── Estado fichajes (ya existente)
  final selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  ).obs;

  void prevMonth() =>
      selectedMonth.value =
          DateTime(selectedMonth.value.year, selectedMonth.value.month - 1);

  void nextMonth() =>
      selectedMonth.value =
          DateTime(selectedMonth.value.year, selectedMonth.value.month + 1);

  // ── Estado CALENDARIO HORARIO (NUEVO)
  final Rx<DateTime> calendarFocusedDay = DateTime.now().obs;
  final RxMap<DateTime, DayEntry> scheduleOverrides = <DateTime, DayEntry>{}.obs;
  final RxList<RecurringShiftRule> scheduleRules = <RecurringShiftRule>[].obs;
  final RxBool isLoadingSchedule = false.obs;

  @override
  void onInit() {
    super.onInit();
    if (Get.arguments is EmployeeModel) {
      initWithEmployee(Get.arguments as EmployeeModel);
      _load();
    } else {
      Get.snackbar('Error', 'No employee data provided');
    }
  }

  Future<void> _load() async {
    final b = computeSimpleBalances(employee: employee.value!, hireDateOverride: employee.value!.createdAt);
    balances.value = b;
  }

  void initWithEmployee(EmployeeModel e) {
    employee.value = e;
    fetch(); // fichajes

    // Carga inicial del horario (año del mes seleccionado + reglas)
    calendarFocusedDay.value = DateTime(selectedMonth.value.year, selectedMonth.value.month, 15);
    _loadScheduleForYear(calendarFocusedDay.value.year);
    _loadRules();
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
      allItems.add(_ClockInOutDisplay(time: m.clockIn,  type: ClockInOutType.entry));
      if (m.clockOut != null) {
        allItems.add(_ClockInOutDisplay(time: m.clockOut!, type: ClockInOutType.exit));
      }
    }
    allItems.sort((a, b) => b.time.compareTo(a.time));

    final groups = groupBy(allItems, (e) => DateTime(e.time.year, e.time.month, e.time.day));
    final last5 = Map<DateTime, List<_ClockInOutDisplay>>.fromEntries(
      groups.entries.toList()
        ..sort((a, b) => b.key.compareTo(a.key))
        ..length = (groups.length >= 5 ? 5 : groups.length),
    );

    groupedClockIns.value = last5;
  }

  void redirectToEmployeeSchedule() {
    if (employee.value == null) {
      Get.snackbar('Error', 'Empleado no definido');
      return;
    }
    Get.toNamed(Routes.companyEmployeeSchedule, arguments: {'employeeId': employee.value!.uid});
  }

  // ──────────────────────────────────────────────
  // HORARIO (NUEVO)
  // ──────────────────────────────────────────────
  // Carga overrides del año
  Future<void> _loadScheduleForYear(int year) async {
    final compId = brain.company.value?.id;
    final empId  = employee.value?.uid;
    if (compId == null || empId == null) return;

    isLoadingSchedule.value = true;
    final res = await getYearScheduleUseCase.call(companyId: compId, employeeId: empId, year: year);
    scheduleOverrides.clear();
    if (res.success) {
      res.data.forEach((k, v) {
        final d = DateTime.parse(k);
        final key = DateTime(d.year, d.month, d.day);
        scheduleOverrides[key] = v;
      });
    }
    isLoadingSchedule.value = false;
  }

  // Carga reglas recurrentes
  Future<void> _loadRules() async {
    final compId = brain.company.value?.id;
    final empId  = employee.value?.uid;
    if (compId == null || empId == null) return;

    final res = await listRecurringRulesUseCase.call(companyId: compId, employeeId: empId);
    if (res.success) {
      scheduleRules.assignAll(res.data);
    }
  }

  // Handler para cambio de página del calendario (cambia de mes/año)
  Future<void> onCalendarPageChanged(DateTime focused) async {
    calendarFocusedDay.value = focused;
    await _loadScheduleForYear(focused.year);
  }

  void reditectToUpsertEmployee(EmployeeModel? employee) {
    Get.toNamed(
      Routes.companyUpsertEmployee,
      arguments: employee,
    );
  }
}

enum ClockInOutType { entry, exit }

class _ClockInOutDisplay {
  final DateTime time;
  final ClockInOutType type;

  _ClockInOutDisplay({required this.time, required this.type});
}