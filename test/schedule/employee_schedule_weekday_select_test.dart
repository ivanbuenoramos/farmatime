// CAND-016: la selección rápida por día de la semana (L M X J V S D) debe
// seleccionar SOLO los días de ese weekday en el mes visible, no el rango
// contiguo entre el primero y el último.
//
// Test unitario puro (sin emulador): el controlador se construye a mano, sin
// Get.put, para que no se ejecute onInit/loadAll.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/schedule/day_entry.dart';
import 'package:farmatime/domain/repositories/employee_schedule_repository.dart';
import 'package:farmatime/domain/usecases/employee_schedule/get_assigned_days_in_year_usecase.dart';
import 'package:farmatime/domain/usecases/employee_schedule/get_employee_month_schedule_usecase.dart';
import 'package:farmatime/domain/usecases/employee_schedule/list_recurring_rules_usecase.dart';
import 'package:farmatime/domain/usecases/employee_schedule/upsert_employee_month_schedule_usecase.dart';
import 'package:farmatime/presentation/pages/company/schedule/company_employee_schedule_controller.dart';

/// Repositorio que no debe tocarse en estos flujos (selección en memoria).
class _NoopRepo implements EmployeeScheduleRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('No debería llamarse al repositorio: $invocation');
}

EmployeeScheduleController _build() {
  Get.testMode = true;
  if (!Get.isRegistered<Brain>()) Get.put<Brain>(Brain());
  final repo = _NoopRepo();
  return EmployeeScheduleController(
    getMonthUC: GetEmployeeMonthScheduleUseCase(repo),
    upsertMonthUC: UpsertEmployeeMonthScheduleUseCase(repo),
    listRulesUC: ListRecurringRulesUseCase(repo),
    getAssignedDaysUC: GetAssignedDaysInYearUseCase(repo),
  );
}

void main() {
  group('selectWeekdayInMonth', () {
    test('pulsar L selecciona solo los lunes del mes visible', () {
      final c = _build();
      c.focusedDay.value = DateTime(2026, 10, 15);

      c.selectWeekdayInMonth(DateTime.monday);

      final dates = c.selectedDates;
      expect(dates.map((d) => d.day).toList(), [5, 12, 19, 26]);
      expect(dates.every((d) => d.weekday == DateTime.monday), isTrue);
      expect(dates.every((d) => d.month == 10 && d.year == 2026), isTrue);
    });

    test('pulsar D selecciona los domingos (incluido el 1 si cae en domingo)', () {
      final c = _build();
      // Febrero 2026 empieza en domingo (1, 8, 15, 22).
      c.focusedDay.value = DateTime(2026, 2, 10);

      c.selectWeekdayInMonth(DateTime.sunday);

      expect(c.selectedDates.map((d) => d.day).toList(), [1, 8, 15, 22]);
    });

    test('newDaysForType cuenta solo los días de ese weekday', () {
      final c = _build();
      c.focusedDay.value = DateTime(DateTime.now().year, 10, 15);

      c.selectWeekdayInMonth(DateTime.monday);

      // Sin nada asignado: tantos días nuevos como lunes tiene el mes.
      final mondays = c.selectedDates.length;
      expect(mondays, inInclusiveRange(4, 5));
      expect(c.newDaysForType(DayType.vacation), mondays);
    });
  });

  group('setForSelection / clearSelection tras selección por weekday', () {
    test('asignar "Libre" a los lunes no toca el resto de días', () async {
      final c = _build();
      c.focusedDay.value = DateTime(2026, 10, 15);
      c.selectWeekdayInMonth(DateTime.monday);

      await c.setForSelection(DayEntry(type: DayType.off));

      expect(c.entryFor(DateTime(2026, 10, 5))?.type, DayType.off);
      expect(c.entryFor(DateTime(2026, 10, 12))?.type, DayType.off);
      expect(c.entryFor(DateTime(2026, 10, 19))?.type, DayType.off);
      expect(c.entryFor(DateTime(2026, 10, 26))?.type, DayType.off);
      // Martes y domingo intermedios quedan sin override.
      expect(c.entryFor(DateTime(2026, 10, 6)), isNull);
      expect(c.entryFor(DateTime(2026, 10, 11)), isNull);
      expect(c.entryFor(DateTime(2026, 10, 25)), isNull);
      expect(c.entries.length, 4);
      expect(c.dirtyMonths, {'2026-10'});
    });

    test('"Quitar asignación" sobre los lunes conserva los demás overrides',
        () async {
      final c = _build();
      c.focusedDay.value = DateTime(2026, 10, 15);

      // Martes 6 con turno, lunes 5 y 12 con vacaciones.
      c.selectSingleDay(DateTime(2026, 10, 6));
      await c.setForSelection(DayEntry(
        type: DayType.work,
        start: const TimeOfDay(hour: 9, minute: 0),
        end: const TimeOfDay(hour: 14, minute: 0),
      ));
      c.selectWeekdayInMonth(DateTime.monday);
      await c.setForSelection(DayEntry(type: DayType.vacation));

      c.selectWeekdayInMonth(DateTime.monday);
      await c.clearSelection();

      expect(c.entryFor(DateTime(2026, 10, 5)), isNull);
      expect(c.entryFor(DateTime(2026, 10, 12)), isNull);
      expect(c.entryFor(DateTime(2026, 10, 6))?.type, DayType.work);
      expect(c.entries.length, 1);
    });
  });

  group('selección contigua (rango y día suelto) sigue funcionando', () {
    test('tocar un día después de L deja un único día seleccionado', () {
      final c = _build();
      c.focusedDay.value = DateTime(2026, 10, 15);
      c.selectWeekdayInMonth(DateTime.monday);

      c.selectSingleDay(DateTime(2026, 10, 7));

      expect(c.selectedDates, [DateTime(2026, 10, 7)]);
    });

    test('un rango después de L sustituye la selección por weekday', () {
      final c = _build();
      c.focusedDay.value = DateTime(2026, 10, 15);
      c.selectWeekdayInMonth(DateTime.monday);

      c.onRangeSelected(
          DateTime(2026, 10, 7), DateTime(2026, 10, 9), DateTime(2026, 10, 7));

      expect(c.selectedDates.map((d) => d.day).toList(), [7, 8, 9]);
    });

    test('un rango que cruza el cambio de hora no duplica ni salta días', () {
      final c = _build();
      c.focusedDay.value = DateTime(2026, 10, 15);

      // En Europe/Madrid el DST termina el 25/10/2026.
      c.onRangeSelected(
          DateTime(2026, 10, 23), DateTime(2026, 10, 27), DateTime(2026, 10, 23));

      final days = c.selectedDates.map((d) => d.day).toList();
      expect(days, [23, 24, 25, 26, 27]);
      expect(c.selectedDates.every((d) => d.hour == 0), isTrue);
    });
  });
}
