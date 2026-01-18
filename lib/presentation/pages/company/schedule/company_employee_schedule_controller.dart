import 'package:farmatime/data/models/shift_template_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/schedule/day_entry.dart';
import 'package:farmatime/data/models/schedule/recurring_shift_rule.dart';
import 'package:farmatime/domain/usecases/employee_schedule/get_employee_month_schedule_usecase.dart';
import 'package:farmatime/domain/usecases/employee_schedule/upsert_employee_month_schedule_usecase.dart';
import 'package:farmatime/domain/usecases/employee_schedule/list_recurring_rules_usecase.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:farmatime/domain/usecases/shift_template/list_shift_templates_usecase.dart';

class EmployeeScheduleController extends GetxController {
  final Brain brain = Get.find<Brain>();

  final GetEmployeeMonthScheduleUseCase getMonthUC;
  final UpsertEmployeeMonthScheduleUseCase upsertMonthUC;
  final ListRecurringRulesUseCase listRulesUC;

  EmployeeScheduleController({
    required this.getMonthUC,
    required this.upsertMonthUC,
    required this.listRulesUC,
  });

  // Parámetro de navegación
  final String employeeId = Get.arguments['employeeId'] ?? '';

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
    ]);

    isLoading.value = false;
  }

  // ── Horario por mes (overrides) ────────────────────────────────────────────
  Future<void> loadMonth(int year, int month) async {
    error.value = null;

    final monthKey = '${year}-${month.toString().padLeft(2, '0')}';

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
        DayType.work => theme.colorScheme.primary.withOpacity(0.25),
        DayType.off => theme.colorScheme.tertiaryContainer.withOpacity(0.35),
        DayType.vacation => theme.colorScheme.errorContainer.withOpacity(0.45),
      };
    }
    // Color por regla cuando no hay override
    final hasRule = rules.any((r) => r.matchesDate(day));
    if (hasRule) return theme.colorScheme.primary.withOpacity(0.18);
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
      Get.snackbar('Sin cambios', 'No hay nada que guardar',
          snackPosition: SnackPosition.BOTTOM);
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
        Get.snackbar('Error', error.value!,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.withOpacity(0.1));
        return;
      }
    }

    dirtyMonths.clear();
    isSaving.value = false;

    Get.snackbar('Guardado', 'Horario actualizado',
        snackPosition: SnackPosition.BOTTOM);
  }

  // ── Entrada calculada (override > regla) ───────────────────────────────────
  DayEntry? computedEntryFor(DateTime day) {
    final override = entryFor(day);
    if (override != null) return override;

    final r = rules.firstWhereOrNull((r) => r.matchesDate(day));
    if (r == null) return null;

    return DayEntry(type: DayType.work, start: r.startTime, end: r.endTime);
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