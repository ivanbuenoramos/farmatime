import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/data/models/shift_template_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/services/toast_service.dart';
import 'package:farmatime/core/utils/leave_simple_utils.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/schedule/day_entry.dart';
import 'package:farmatime/data/models/schedule/recurring_shift_rule.dart';
import 'package:farmatime/domain/usecases/employee_schedule/get_employee_month_schedule_usecase.dart';
import 'package:farmatime/domain/usecases/employee_schedule/get_assigned_days_in_year_usecase.dart';
import 'package:farmatime/domain/usecases/employee_schedule/upsert_employee_month_schedule_usecase.dart';
import 'package:farmatime/domain/usecases/employee_schedule/list_recurring_rules_usecase.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:farmatime/domain/usecases/shift_template/list_shift_templates_usecase.dart';

/// Origen de la entrada efectiva de un día en el calendario.
enum DayEntrySource { override, rule, none }

class EmployeeScheduleController extends GetxController {
  final Brain brain = Get.find<Brain>();

  final GetEmployeeMonthScheduleUseCase getMonthUC;
  final UpsertEmployeeMonthScheduleUseCase upsertMonthUC;
  final ListRecurringRulesUseCase listRulesUC;
  final GetAssignedDaysInYearUseCase getAssignedDaysUC;

  EmployeeScheduleController({
    required this.getMonthUC,
    required this.upsertMonthUC,
    required this.listRulesUC,
    required this.getAssignedDaysUC,
  });

  // Parámetro de navegación
  final String employeeId = (Get.arguments as Map?)?['employeeId'] as String? ?? '';
  final String employeeName =
      (Get.arguments as Map?)?['employeeName'] as String? ?? '';

  // ── Saldos de vacaciones / asuntos propios ─────────────────────────────────
  /// Empleado actual (para devengados). Se resuelve desde Brain.
  EmployeeModel? _employee;

  /// Días devengados (totales) en el año natural en curso.
  final RxDouble vacationEarned = 0.0.obs;
  final RxDouble personalEarned = 0.0.obs;

  /// Fechas (yyyy-MM-dd) ya asignadas este año, por tipo. Incluyen tanto
  /// solicitudes aprobadas como días marcados a mano (ambos viven como
  /// overrides en employee_schedule_months → sin doble conteo).
  final RxSet<String> assignedVacationDays = <String>{}.obs;
  final RxSet<String> assignedPersonalDays = <String>{}.obs;

  final RxBool balancesReady = false.obs;

  int get _currentYear => DateTime.now().year;

  // Estado calendario
  final Rx<DateTime> focusedDay = DateTime.now().obs;
  final Rx<DateTime?> selectedDay = Rx<DateTime?>(DateTime.now());

  // ⚠️ Este map representa SIEMPRE el mes actualmente visible en UI
  final RxMap<DateTime, DayEntry> entries = <DateTime, DayEntry>{}.obs;

  // Cache por mes: 'yyyy-MM' -> (dateOnly -> DayEntry)
  final Map<String, Map<DateTime, DayEntry>> _cacheByMonth = {};
  final RxSet<String> dirtyMonths = <String>{}.obs;

  // Selección por rango
  final Rx<DateTime?> rangeStart = Rx<DateTime?>(null);
  final Rx<DateTime?> rangeEnd = Rx<DateTime?>(null);
  final Rx<RangeSelectionMode> rangeSelectionMode =
      RangeSelectionMode.toggledOff.obs;

  // Reglas recurrentes
  final RxList<RecurringShiftRule> rules = <RecurringShiftRule>[].obs;

  // Turnos preestablecidos
  final RxList<ShiftTemplate> shiftTemplates = <ShiftTemplate>[].obs;

  // UI state
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxnString error = RxnString();

  String get _companyId => brain.company.value!.id;

  String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _yMd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get _currentMonthKey => _monthKey(focusedDay.value);

  @override
  void onInit() {
    super.onInit();
    loadAll();
  }

  Future<void> loadAll() async {
    isLoading.value = true;

    await Future.wait([
      loadMonth(focusedDay.value.year, focusedDay.value.month),
      loadRules(),
      loadShiftTemplates(),
      loadBalances(),
    ]);

    isLoading.value = false;
  }

  // ── Saldos de vacaciones / asuntos propios ─────────────────────────────────
  Future<void> loadBalances() async {
    // Resolvemos el empleado desde el estado global.
    _employee = brain.companyEmployees.firstWhereOrNull((e) => e.uid == employeeId);
    final emp = _employee;
    if (emp == null) {
      balancesReady.value = false;
      return;
    }

    // Devengado por tiempo trabajado, a día de hoy.
    final earned = earnedByTime(employee: emp, hireDateOverride: emp.createdAt);
    vacationEarned.value = earned.vacationEarned;
    personalEarned.value = earned.personalEarned;

    // Días ya asignados este año (vacaciones y asuntos propios) en el calendario.
    final results = await Future.wait([
      getAssignedDaysUC.call(
        companyId: _companyId,
        employeeId: employeeId,
        year: _currentYear,
        type: DayType.vacation,
      ),
      getAssignedDaysUC.call(
        companyId: _companyId,
        employeeId: employeeId,
        year: _currentYear,
        type: DayType.personal,
      ),
    ]);

    if (results[0].success) assignedVacationDays.assignAll(results[0].data);
    if (results[1].success) assignedPersonalDays.assignAll(results[1].data);

    balancesReady.value = true;
  }

  /// Días disponibles (devengado − asignados este año), nunca negativo.
  double get vacationAvailable {
    final v = vacationEarned.value - assignedVacationDays.length;
    return v < 0 ? 0 : v;
  }

  double get personalAvailable {
    final v = personalEarned.value - assignedPersonalDays.length;
    return v < 0 ? 0 : v;
  }

  /// Conjunto de días asignados del tipo dado (this year), normalizado.
  Set<String> _assignedFor(DayType type) =>
      type == DayType.vacation ? assignedVacationDays : assignedPersonalDays;

  /// Cuántos días NUEVOS del año actual añadiría asignar [type] a las fechas
  /// actualmente seleccionadas (excluye los que ya estén marcados de ese tipo
  /// y los de otros años, que no cuentan para el saldo anual).
  int newDaysForType(DayType type) {
    final already = _assignedFor(type);
    var count = 0;
    for (final d in selectedDates) {
      if (d.year != _currentYear) continue; // el saldo es anual
      final key = _yMd(_dateOnly(d));
      if (!already.contains(key)) count++;
    }
    return count;
  }

  /// Días disponibles para el tipo dado.
  double availableFor(DayType type) =>
      type == DayType.vacation ? vacationAvailable : personalAvailable;

  /// ¿La asignación de [type] a la selección actual supera el saldo disponible?
  bool exceedsBalance(DayType type) =>
      newDaysForType(type) > availableFor(type);

  /// Cuántos días excederían el saldo (para el mensaje de la alerta).
  int overflowFor(DayType type) {
    final overflow = newDaysForType(type) - availableFor(type);
    return overflow > 0 ? overflow.ceil() : 0;
  }

  // ── Horario por mes (overrides) ────────────────────────────────────────────
  Future<void> loadMonth(int year, int month) async {
    error.value = null;

    final monthKey = '$year-${month.toString().padLeft(2, '0')}';

    final Result<Map<String, DayEntry>> res = await getMonthUC.call(
      companyId: _companyId,
      employeeId: employeeId,
      year: year,
      month: month,
    );

    final mapped = <DateTime, DayEntry>{};
    if (res.success) {
      res.data.forEach((k, v) {
        final d = DateTime.parse(k);
        mapped[_dateOnly(d)] = v;
      });
      _cacheByMonth[monthKey] = mapped;
      // si el mes cargado es el visible, reflejamos en entries
      if (monthKey == _currentMonthKey) {
        entries.assignAll(mapped);
      }
    } else {
      error.value = 'Error al cargar el horario';
      // Aun así inicializamos cache vacío para no romper UI
      _cacheByMonth.putIfAbsent(monthKey, () => <DateTime, DayEntry>{});
      if (monthKey == _currentMonthKey) {
        entries.clear();
      }
    }
  }

  // ── Reglas recurrentes ─────────────────────────────────────────────────────
  Future<void> loadRules() async {
    final res = await listRulesUC.call(companyId: _companyId, employeeId: employeeId);
    if (res.success) rules.assignAll(res.data);
  }

  // ── Turnos (templates) ─────────────────────────────────────────────────────
  Future<void> loadShiftTemplates() async {
    final uc = Get.find<ListShiftTemplatesUseCase>();
    final res = await uc.call(_companyId);
    if (res.success) shiftTemplates.assignAll(res.data);
  }

  // ── Interacción calendario ─────────────────────────────────────────────────
  void onDaySelected(DateTime selected, DateTime focused) {
    selectedDay.value = _dateOnly(selected);
    focusedDay.value = focused;
    rangeStart.value = null;
    rangeEnd.value = null;
    rangeSelectionMode.value = RangeSelectionMode.toggledOff;
  }

  void onRangeSelected(DateTime? start, DateTime? end, DateTime focused) {
    selectedDay.value = null;
    focusedDay.value = focused;
    rangeStart.value = start != null ? _dateOnly(start) : null;
    rangeEnd.value = end != null ? _dateOnly(end) : null;
    rangeSelectionMode.value = RangeSelectionMode.toggledOn;
  }

  // --- Lectura override (usa cache por mes) ---
  DayEntry? entryFor(DateTime day) {
    final d = _dateOnly(day);
    final key = _monthKey(d);
    final map = _cacheByMonth[key];
    return map?[d];
  }

  Color colorFor(DateTime day, ThemeData theme) {
    final e = entryFor(day);
    if (e != null) {
      return switch (e.type) {
        DayType.work => theme.colorScheme.primary.withValues(alpha: 0.25),
        DayType.off => theme.colorScheme.tertiaryContainer.withValues(alpha: 0.35),
        DayType.vacation => theme.colorScheme.errorContainer.withValues(alpha: 0.45),
        DayType.personal => const Color(0xff8B5CF6).withValues(alpha: 0.28),
      };
    }
    // Color por regla cuando no hay override
    final hasRule = rules.any((r) => r.matchesDate(day));
    if (hasRule) return theme.colorScheme.primary.withValues(alpha: 0.18);
    return theme.colorScheme.surfaceContainerHighest;
  }

  // ── Mutaciones de selección ────────────────────────────────────────────────
  Future<void> setForSelection(DayEntry entry) async {
    // Rango
    if (rangeSelectionMode.value == RangeSelectionMode.toggledOn &&
        rangeStart.value != null &&
        rangeEnd.value != null) {
      DateTime d = rangeStart.value!;
      while (!d.isAfter(rangeEnd.value!)) {
        _setEntryForDate(d, entry);
        d = d.add(const Duration(days: 1));
      }
    }
    // Día suelto
    else if (selectedDay.value != null) {
      _setEntryForDate(selectedDay.value!, entry);
    }

    // Refrescamos map visible (mes actual)
    entries.assignAll(_cacheByMonth[_currentMonthKey] ?? {});
    update();
  }

  void _setEntryForDate(DateTime date, DayEntry entry) {
    final d = _dateOnly(date);
    final mk = _monthKey(d);

    final map = _cacheByMonth.putIfAbsent(mk, () => <DateTime, DayEntry>{});
    map[d] = entry;

    dirtyMonths.add(mk);
  }

  Future<void> clearSelection() async {
    if (rangeSelectionMode.value == RangeSelectionMode.toggledOn &&
        rangeStart.value != null &&
        rangeEnd.value != null) {
      DateTime d = rangeStart.value!;
      while (!d.isAfter(rangeEnd.value!)) {
        _removeEntryForDate(d);
        d = d.add(const Duration(days: 1));
      }
    } else if (selectedDay.value != null) {
      _removeEntryForDate(selectedDay.value!);
    }

    entries.assignAll(_cacheByMonth[_currentMonthKey] ?? {});
    update();
  }

  void _removeEntryForDate(DateTime date) {
    final d = _dateOnly(date);
    final mk = _monthKey(d);

    final map = _cacheByMonth.putIfAbsent(mk, () => <DateTime, DayEntry>{});
    if (map.remove(d) != null) {
      dirtyMonths.add(mk);
    }
  }

  // ── Guardar ────────────────────────────────────────────────────────────────
  Future<void> save() async {
    if (dirtyMonths.isEmpty) {
      ToastService().show(
          title: 'Sin cambios',
          message: 'No hay nada que guardar',
          type: ToastType.warning);
      return;
    }

    isSaving.value = true;
    error.value = null;

    // Guardamos cada mes tocado
    final monthsToSave = dirtyMonths.toList()..sort();

    for (final mk in monthsToSave) {
      final parts = mk.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);

      final map = _cacheByMonth[mk] ?? {};
      final out = <String, DayEntry>{};
      map.forEach((date, entry) {
        out[_yMd(date)] = entry;
      });

      final res = await upsertMonthUC.call(
        companyId: _companyId,
        employeeId: employeeId,
        year: year,
        month: month,
        entries: out,
      );

      if (!res.success) {
        isSaving.value = false;
        error.value = 'No se pudo guardar ($mk)';
        ToastService().show(
            title: 'Error',
            message: error.value!,
            type: ToastType.error);
        return;
      }
    }

    dirtyMonths.clear();
    isSaving.value = false;

    // Recalcula saldos: los días recién guardados ya cuentan como asignados.
    await loadBalances();

    ToastService().show(
        title: 'Guardado',
        message: 'Horario actualizado',
        type: ToastType.success);
  }

  // ── Entrada calculada (override > regla) ───────────────────────────────────
  DayEntry? computedEntryFor(DateTime day) {
    final override = entryFor(day);
    if (override != null) return override;

    final r = rules.firstWhereOrNull((r) => r.matchesDate(day));
    if (r == null) return null;

    return DayEntry(type: DayType.work, start: r.startTime, end: r.endTime);
  }

  // ── Helpers para la UI rediseñada ──────────────────────────────────────────

  /// ¿Hay cambios sin guardar?
  bool get hasUnsavedChanges => dirtyMonths.isNotEmpty;

  /// Origen de la entrada efectiva de un día.
  /// `override` -> editado manualmente · `rule` -> por regla recurrente · `none`.
  DayEntrySource sourceFor(DateTime day) {
    if (entryFor(day) != null) return DayEntrySource.override;
    if (rules.any((r) => r.matchesDate(day))) return DayEntrySource.rule;
    return DayEntrySource.none;
  }

  /// Selecciona un único día (usado al tocar en el calendario).
  void selectSingleDay(DateTime day) {
    selectedDay.value = _dateOnly(day);
    rangeStart.value = null;
    rangeEnd.value = null;
    rangeSelectionMode.value = RangeSelectionMode.toggledOff;
    update();
  }

  /// Selecciona todos los días del mes visible que caen en [weekday] (1..7).
  void selectWeekdayInMonth(int weekday) {
    final focused = focusedDay.value;
    final first = DateTime(focused.year, focused.month, 1);
    final daysInMonth = DateTime(focused.year, focused.month + 1, 0).day;

    final matches = <DateTime>[];
    for (var i = 0; i < daysInMonth; i++) {
      final d = first.add(Duration(days: i));
      if (d.weekday == weekday) matches.add(d);
    }
    if (matches.isEmpty) return;

    selectedDay.value = null;
    rangeStart.value = matches.first;
    rangeEnd.value = matches.last;
    rangeSelectionMode.value = RangeSelectionMode.toggledOn;
    update();
  }

  /// Días actualmente seleccionados (1 día o un rango). Vacío si no hay nada.
  List<DateTime> get selectedDates {
    if (rangeSelectionMode.value == RangeSelectionMode.toggledOn &&
        rangeStart.value != null &&
        rangeEnd.value != null) {
      final out = <DateTime>[];
      var d = rangeStart.value!;
      while (!d.isAfter(rangeEnd.value!)) {
        out.add(d);
        d = d.add(const Duration(days: 1));
      }
      return out;
    }
    if (selectedDay.value != null) return [selectedDay.value!];
    return const [];
  }

  bool get hasSelection => selectedDates.isNotEmpty;

  /// Duración de un turno (maneja cruce de medianoche). null si no aplica.
  Duration? workDurationOf(DayEntry? e) {
    if (e == null || e.type != DayType.work || e.start == null || e.end == null) {
      return null;
    }
    final startM = e.start!.hour * 60 + e.start!.minute;
    final endM = e.end!.hour * 60 + e.end!.minute;
    final minutes = endM >= startM ? endM - startM : (24 * 60 - startM + endM);
    if (minutes <= 0) return null;
    return Duration(minutes: minutes);
  }

  // ── Page changed ───────────────────────────────────────────────────────────
  Future<void> onPageChanged(DateTime focused) async {
    focusedDay.value = focused;

    final mk = _monthKey(focused);
    if (!_cacheByMonth.containsKey(mk)) {
      await loadMonth(focused.year, focused.month);
    } else {
      entries.assignAll(_cacheByMonth[mk] ?? {});
    }
  }
}