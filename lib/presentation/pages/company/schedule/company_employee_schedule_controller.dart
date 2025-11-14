import 'package:farmatime/data/models/shift_template_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/schedule/day_entry.dart';
import 'package:farmatime/data/models/schedule/recurring_shift_rule.dart';
import 'package:farmatime/domain/usecases/employee_schedule/get_employee_year_schedule_usecase.dart';
import 'package:farmatime/domain/usecases/employee_schedule/upsert_employee_year_schedule_usecase.dart';
import 'package:farmatime/domain/usecases/employee_schedule/list_recurring_rules_usecase.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:farmatime/domain/usecases/shift_template/list_shift_templates_usecase.dart';

class EmployeeScheduleController extends GetxController {
  final Brain brain = Get.find<Brain>();
  final GetEmployeeYearScheduleUseCase getYearUC;
  final UpsertEmployeeYearScheduleUseCase upsertYearUC;
  final ListRecurringRulesUseCase listRulesUC;

  EmployeeScheduleController({
    required this.getYearUC,
    required this.upsertYearUC,
    required this.listRulesUC,
  });

  // Parámetro de navegación
  final String employeeId = Get.arguments['employeeId'] ?? '';

  // Estado calendario (overrides)
  final Rx<DateTime> focusedDay = DateTime.now().obs;
  final Rx<DateTime?> selectedDay = Rx<DateTime?>(DateTime.now());
  final RxMap<DateTime, DayEntry> entries = <DateTime, DayEntry>{}.obs;

  // Selección por rango
  final Rx<DateTime?> rangeStart = Rx<DateTime?>(null);
  final Rx<DateTime?> rangeEnd = Rx<DateTime?>(null);
  final Rx<RangeSelectionMode> rangeSelectionMode = RangeSelectionMode.toggledOff.obs;

  // Reglas recurrentes
  final RxList<RecurringShiftRule> rules = <RecurringShiftRule>[].obs;

  // Turnos preestablecidos
  final RxList<ShiftTemplate> shiftTemplates = <ShiftTemplate>[].obs;

  // UI state
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxnString error = RxnString();

  String get _companyId => brain.company.value!.id;
  int get _year => focusedDay.value.year;

  @override
  void onInit() {
    super.onInit();
    loadAll();
  }

  Future<void> loadAll() async {
    isLoading.value = true;
    await Future.wait([
      loadYear(_year),
      loadRules(),
      loadShiftTemplates(),
    ]);
    isLoading.value = false;
  }

  // ── Horario por año (overrides) ─────────────────────────────────────────────
  Future<void> loadYear(int year) async {
    error.value = null;
    final Result<Map<String, DayEntry>> res = await getYearUC.call(
      companyId: _companyId,
      employeeId: employeeId,
      year: year,
    );
    entries.clear();
    if (res.success) {
      res.data.forEach((k, v) => entries[DateTime.parse(k)] = v);
    } else {
      error.value = 'Error al cargar el horario';
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
    if (res.success) {
      shiftTemplates.assignAll(res.data);
    }
  }

  // ── Interacción calendario ─────────────────────────────────────────────────
  void onDaySelected(DateTime selected, DateTime focused) {
    selectedDay.value = dateOnly(selected);
    focusedDay.value = focused;
    rangeStart.value = null;
    rangeEnd.value = null;
    rangeSelectionMode.value = RangeSelectionMode.toggledOff;
  }

  void onRangeSelected(DateTime? start, DateTime? end, DateTime focused) {
    selectedDay.value = null;
    focusedDay.value = focused;
    rangeStart.value = start != null ? dateOnly(start) : null;
    rangeEnd.value = end != null ? dateOnly(end) : null;
    rangeSelectionMode.value = RangeSelectionMode.toggledOn;
  }

  DayEntry? entryFor(DateTime day) => entries[dateOnly(day)];

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
    final Map<DateTime, DayEntry> newMap = Map.of(entries);
    if (rangeSelectionMode.value == RangeSelectionMode.toggledOn &&
        rangeStart.value != null &&
        rangeEnd.value != null) {
      DateTime d = rangeStart.value!;
      while (!d.isAfter(rangeEnd.value!)) {
        newMap[dateOnly(d)] = entry;
        d = d.add(const Duration(days: 1));
      }
    } else if (selectedDay.value != null) {
      newMap[dateOnly(selectedDay.value!)] = entry;
    }
    entries.assignAll(newMap);
    update();
  }

  Future<void> clearSelection() async {
    if (rangeSelectionMode.value == RangeSelectionMode.toggledOn &&
        rangeStart.value != null &&
        rangeEnd.value != null) {
      DateTime d = rangeStart.value!;
      while (!d.isAfter(rangeEnd.value!)) {
        entries.remove(dateOnly(d));
        d = d.add(const Duration(days: 1));
      }
    } else if (selectedDay.value != null) {
      entries.remove(dateOnly(selectedDay.value!));
    }
    update();
  }

  Future<void> save() async {
    isSaving.value = true;
    error.value = null;

    final out = <String, DayEntry>{};
    entries.forEach((date, entry) {
      if (date.year == _year) out[yMd(date)] = entry;
    });

    final res = await upsertYearUC.call(
      companyId: _companyId,
      employeeId: employeeId,
      year: _year,
      entries: out,
    );

    isSaving.value = false;

    if (!res.success) {
      error.value = 'No se pudo guardar';
      Get.snackbar('Error', error.value!,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.1));
      return;
    }
    Get.snackbar('Guardado', 'Horario actualizado',
        snackPosition: SnackPosition.BOTTOM);
  }

  // Entrada calculada (override > regla)
  DayEntry? computedEntryFor(DateTime day) {
    final override = entryFor(day);
    if (override != null) return override;
    final r = rules.firstWhereOrNull((r) => r.matchesDate(day));
    if (r == null) return null;
    return DayEntry(type: DayType.work, start: r.startTime, end: r.endTime);
  }
}