import 'package:flutter_test/flutter_test.dart';

import 'package:farmatime/core/utils/work_hour_summary.dart';
import 'package:farmatime/data/models/clock_in_out_model.dart';
import 'package:farmatime/data/models/schedule/recurring_shift_rule.dart';

ClockInOutModel _record({
  required DateTime clockIn,
  DateTime? clockOut,
}) =>
    ClockInOutModel(
      id: 'r',
      companyId: 'c',
      employeeId: 'e',
      clockIn: clockIn,
      clockOut: clockOut,
      isEdited: false,
      editedFields: const [],
      createdAt: clockIn,
      updatedAt: clockIn,
    );

void main() {
  group('computeWorkHoursSummary — horas esperadas', () {
    test('turno diurno normal', () {
      // Lunes 2026-07-06, turno 09:00-17:00.
      final summary = computeWorkHoursSummary(
        records: [
          _record(
            clockIn: DateTime(2026, 7, 6, 9),
            clockOut: DateTime(2026, 7, 6, 17),
          ),
        ],
        rules: [
          RecurringShiftRule(
            id: 'rule',
            start: '0900',
            end: '1700',
            weekdays: const [1],
            startsOn: DateTime(2026, 1, 1),
            endsOn: null,
            active: true,
          ),
        ],
        rangeStart: DateTime(2026, 7, 6),
        rangeEnd: DateTime(2026, 7, 6),
        nowOverride: DateTime(2026, 7, 8),
      );

      expect(summary.totalExpected.inMinutes, 8 * 60);
      expect(summary.totalWorked.inMinutes, 8 * 60);
      expect(summary.difference, Duration.zero);
    });

    test('turno nocturno 22:00→06:00 cuenta 8h esperadas', () {
      // Lunes 2026-07-06 22:00 → martes 07 06:00. Rango: lunes y martes.
      final summary = computeWorkHoursSummary(
        records: [
          _record(
            clockIn: DateTime(2026, 7, 6, 22),
            clockOut: DateTime(2026, 7, 7, 6),
          ),
        ],
        rules: [
          RecurringShiftRule(
            id: 'noche',
            start: '2200',
            end: '0600',
            weekdays: const [1],
            startsOn: DateTime(2026, 1, 1),
            endsOn: null,
            active: true,
          ),
        ],
        rangeStart: DateTime(2026, 7, 6),
        rangeEnd: DateTime(2026, 7, 7),
        nowOverride: DateTime(2026, 7, 8),
      );

      // Antes del fix la regla se descartaba y esperadas = 0.
      expect(summary.totalExpected.inMinutes, closeTo(8 * 60, 1));
      // Repartidas igual que las trabajadas: 2h el lunes, 6h el martes.
      expect(
        summary.expectedPerDay[DateTime(2026, 7, 6)]!.inMinutes,
        closeTo(2 * 60, 1),
      );
      expect(
        summary.expectedPerDay[DateTime(2026, 7, 7)]!.inMinutes,
        closeTo(6 * 60, 1),
      );
      expect(summary.difference.inMinutes.abs(), lessThanOrEqualTo(1));
    });

    test('turno nocturno del día anterior al rango aporta su madrugada', () {
      // Regla nocturna del lunes; el rango empieza el martes: deben contar
      // las 6h de madrugada del martes (00:00-06:00).
      final summary = computeWorkHoursSummary(
        records: [
          _record(
            clockIn: DateTime(2026, 7, 7, 0),
            clockOut: DateTime(2026, 7, 7, 6),
          ),
        ],
        rules: [
          RecurringShiftRule(
            id: 'noche',
            start: '2200',
            end: '0600',
            weekdays: const [1],
            startsOn: DateTime(2026, 1, 1),
            endsOn: null,
            active: true,
          ),
        ],
        rangeStart: DateTime(2026, 7, 7),
        rangeEnd: DateTime(2026, 7, 7),
        nowOverride: DateTime(2026, 7, 8),
      );

      expect(summary.totalExpected.inMinutes, closeTo(6 * 60, 1));
    });
  });
}
