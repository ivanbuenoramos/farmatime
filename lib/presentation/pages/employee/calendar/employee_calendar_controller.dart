// lib/presentation/pages/employee/calendar/employee_calendar_controller.dart
import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/routes/routes.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

import 'package:farmatime/data/models/schedule/day_entry.dart';
import 'package:farmatime/data/models/schedule/recurring_shift_rule.dart';

import 'package:farmatime/domain/usecases/employee_schedule/get_employee_month_schedule_usecase.dart';
import 'package:farmatime/domain/usecases/employee_schedule/list_recurring_rules_usecase.dart';

class EmployeeCalendarController extends GetxController {
  EmployeeCalendarController({
    required this.getMonthScheduleUseCase,
    required this.listRecurringRulesUseCase,
  });

  final GetEmployeeMonthScheduleUseCase getMonthScheduleUseCase;
  final ListRecurringRulesUseCase listRecurringRulesUseCase;

  final Brain brain = Get.find<Brain>();

  // Estado del calendario
  final Rx<DateTime> selectedDay = DateTime.now().obs;
  final Rx<DateTime> focusedDay = DateTime.now().obs;

  // Rango visible
  late final Rx<DateTime> firstDay =
      DateTime(DateTime.now().year - 1, 1, 1).obs;
  late final Rx<DateTime> lastDay =
      DateTime(DateTime.now().year + 1, 12, 31).obs;

  // Datos para el widget (solo overrides cargados)
  final overridesByDay = <DateTime, DayEntry>{}.obs;
  final rules = <RecurringShiftRule>[].obs;

  // Estado
  final isLoading = false.obs;
  final errorText = RxnString();

  // Cache por mes: 'yyyy-MM' -> { DateTime(day) : DayEntry }
  final Map<String, Map<DateTime, DayEntry>> _monthCache = {};
  bool _rulesLoaded = false;

  String get _companyId => brain.employee.value!.companyId;
  String get _employeeId => brain.employee.value!.uid;

  @override
  void onInit() {
    super.onInit();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Carga el mes actual + reglas + precarga del siguiente mes
    await _ensureDataForMonth(focusedDay.value);
    await _ensureRulesLoaded();
    await _ensureDataForMonth(_addMonths(focusedDay.value, 1), prefetch: true);
    _rebuildOverrides();
  }

  void onDaySelected(DateTime selected, DateTime focused) async {
    selectedDay.value = _dateOnly(selected);

    final changedMonth = focused.year != focusedDay.value.year ||
        focused.month != focusedDay.value.month;

    if (changedMonth) {
      await _ensureDataForMonth(focused);
      await _ensureDataForMonth(_addMonths(focused, 1), prefetch: true);
      _rebuildOverrides();
    }

    focusedDay.value = _dateOnly(focused);
  }

  Future<void> onCalendarPageChanged(DateTime newFocusedDay) async {
    final changedMonth = newFocusedDay.year != focusedDay.value.year ||
        newFocusedDay.month != focusedDay.value.month;

    if (changedMonth) {
      await _ensureDataForMonth(newFocusedDay);
      await _ensureDataForMonth(_addMonths(newFocusedDay, 1), prefetch: true);
      _rebuildOverrides();
    }

    focusedDay.value = _dateOnly(newFocusedDay);
  }

  // ─────────────────────────────────────────────────────────────
  // Carga mensual (overrides del mes)
  // ─────────────────────────────────────────────────────────────

  Future<void> _ensureDataForMonth(DateTime anyDayInMonth,
      {bool prefetch = false}) async {
    final monthKey = _monthKey(anyDayInMonth);
    if (_monthCache.containsKey(monthKey)) return;

    if (!prefetch) {
      isLoading.value = true;
      errorText.value = null;
    }

    try {
      final res = await getMonthScheduleUseCase.call(
        companyId: _companyId,
        employeeId: _employeeId,
        year: anyDayInMonth.year,
        month: anyDayInMonth.month, // 1..12
      );

      if (!res.success) {
        if (!prefetch) {
          errorText.value = 'No se pudo cargar el calendario ($monthKey)';
        }
        _monthCache[monthKey] = {};
        return;
      }

      // res.data: Map<String(yyyy-MM-dd), DayEntry>
      final mapped = <DateTime, DayEntry>{};
      res.data.forEach((k, entry) {
        final d = DateTime.parse(k);
        mapped[_dateOnly(d)] = entry;
      });

      _monthCache[monthKey] = mapped;
    } catch (e) {
      if (!prefetch) {
        errorText.value = 'Error al cargar calendario: $e';
      }
      _monthCache[monthKey] = {};
    } finally {
      if (!prefetch) isLoading.value = false;
    }
  }

  Future<void> _ensureRulesLoaded() async {
    if (_rulesLoaded) return;

    try {
      final res = await listRecurringRulesUseCase.call(
        companyId: _companyId,
        employeeId: _employeeId,
      );

      if (res.success) {
        rules.assignAll(res.data);
      } else {
        errorText.value = 'No se pudieron cargar las reglas';
      }
    } catch (e) {
      errorText.value = 'Error al cargar reglas: $e';
    } finally {
      _rulesLoaded = true;
    }
  }

  void _rebuildOverrides() {
    // Mostramos lo cacheado (mes actual + lo precargado)
    final out = <DateTime, DayEntry>{};
    for (final m in _monthCache.values) {
      out.addAll(m);
    }
    overridesByDay
      ..clear()
      ..addAll(out);
  }

  // ─────────────────────────────────────────────────────────────
  // Helpers para pintar el día
  // ─────────────────────────────────────────────────────────────

  DayEntry? entryFor(DateTime day) {
    final normalized = _dateOnly(day);
    return overridesByDay[normalized];
  }

  // Si no hay override, intenta regla recurrente
  RecurringShiftRule? ruleFor(DateTime day) {
    for (final r in rules) {
      if (r.matchesDate(day)) return r;
    }
    return null;
  }

  bool isVacation(DateTime day) {
    final e = entryFor(day);
    if (e != null) return e.type == DayType.vacation;

    // sin override: una regla recurrente implica "laboral"
    return false;
  }

  List<String> shiftsFor(DateTime day) {
    final e = entryFor(day);
    if (e != null) {
      if (e.type != DayType.work) return const [];
      if (e.start == null || e.end == null) return const [];
      return ['• De ${_fmtTod(e.start!)} a ${_fmtTod(e.end!)}'];
    }

    // sin override → regla
    final r = ruleFor(day);
    if (r == null) return const [];
    return ['• De ${_fmtTod(r.startTime)} a ${_fmtTod(r.endTime)}'];
  }

  String _fmtTod(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ─────────────────────────────────────────────────────────────
  // Navegación
  // ─────────────────────────────────────────────────────────────

  void redirectToRequestLeave() {
    Get.toNamed(Routes.employeeRequestLeave);
  }

  // ─────────────────────────────────────────────────────────────
  // Utils
  // ─────────────────────────────────────────────────────────────

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _monthKey(DateTime d) => DateFormat('yyyy-MM').format(d);

  DateTime _addMonths(DateTime d, int months) {
    // DateTime normaliza automáticamente year/mes (ej: month 13)
    return DateTime(d.year, d.month + months, 15);
  }
}