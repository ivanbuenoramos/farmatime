import 'package:flutter/material.dart';

import '../../data/models/clock_in_out_model.dart';
import '../../data/models/schedule/recurring_shift_rule.dart';

/// Resultado del cálculo de horas trabajadas vs esperadas
class WorkHoursSummary {
  /// Horas realmente trabajadas (suma de todos los fichajes) en el rango.
  final Duration totalWorked;

  /// Horas que debería haber trabajado según el horario en el rango.
  final Duration totalExpected;

  /// Diferencia = worked - expected (positivo => ha trabajado de más).
  final Duration difference;

  /// Fecha (solo día) de inicio del rango usado.
  final DateTime from;

  /// Fecha (solo día) de fin del rango usado (inclusive).
  final DateTime to;

  /// Mapa día → horas trabajadas ese día.
  final Map<DateTime, Duration> workedPerDay;

  /// Mapa día → horas esperadas ese día.
  final Map<DateTime, Duration> expectedPerDay;

  const WorkHoursSummary({
    required this.totalWorked,
    required this.totalExpected,
    required this.difference,
    required this.from,
    required this.to,
    required this.workedPerDay,
    required this.expectedPerDay,
  });

  /// Horas totales en formato double (por comodidad).
  double get totalWorkedHours => totalWorked.inMinutes / 60.0;
  double get totalExpectedHours => totalExpected.inMinutes / 60.0;
  double get differenceHours => difference.inMinutes / 60.0;
}

/// Normaliza a fecha sin hora
DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Fin de día (23:59:59.999)
DateTime _endOfDay(DateTime d) =>
    DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

/// TimeOfDay → DateTime en un día concreto
DateTime _onDate(TimeOfDay t, DateTime day) =>
    DateTime(day.year, day.month, day.day, t.hour, t.minute);

/// Calcula horas trabajadas y esperadas para un empleado en un rango.
///
/// - [records] deben ser solo los fichajes de ese empleado (y empresa).
/// - [rules] son las reglas recurrentes de horario que le aplican.
/// - [rangeStart], [rangeEnd] son opcionales:
///   - Si no se pasa rango, se usa todo el histórico de fichajes.
/// - [nowOverride] permite fijar un "ahora" para testear; por defecto DateTime.now().
@visibleForTesting
WorkHoursSummary computeWorkHoursSummary({
  required List<ClockInOutModel> records,
  required List<RecurringShiftRule> rules,
  DateTime? rangeStart,
  DateTime? rangeEnd,
  DateTime? nowOverride,
}) {
  final now = nowOverride ?? DateTime.now();

  if (records.isEmpty) {
    // Si no hay fichajes, intentamos al menos montar rango a partir de hoy
    final today = _dateOnly(now);
    final emptyMap = <DateTime, Duration>{};
    return WorkHoursSummary(
      totalWorked: Duration.zero,
      totalExpected: Duration.zero,
      difference: Duration.zero,
      from: today,
      to: today,
      workedPerDay: emptyMap,
      expectedPerDay: emptyMap,
    );
  }

  // Determinar rango (si no se pasa, usamos todo el histórico del empleado)
  DateTime minStart = records
      .map((r) => r.clockIn)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  DateTime maxEnd = records
      .map((r) => r.clockOut ?? r.clockIn)
      .reduce((a, b) => a.isAfter(b) ? a : b);

  DateTime fromDate = _dateOnly(rangeStart ?? minStart);
  DateTime toDate = _dateOnly(rangeEnd ?? maxEnd);
  if (toDate.isBefore(fromDate)) {
    // Rango inválido → todo a cero
    final emptyMap = <DateTime, Duration>{};
    return WorkHoursSummary(
      totalWorked: Duration.zero,
      totalExpected: Duration.zero,
      difference: Duration.zero,
      from: fromDate,
      to: fromDate,
      workedPerDay: emptyMap,
      expectedPerDay: emptyMap,
    );
  }

  final rangeStartDateTime = fromDate;
  final rangeEndDateTime = _endOfDay(toDate);

  // 1) Horas trabajadas reales por día
  final Map<DateTime, Duration> workedPerDay = {};

  for (final r in records) {
    final intervalStart = r.clockIn;
    final intervalEndRaw = r.clockOut ?? now;

    if (intervalEndRaw.isBefore(intervalStart)) {
      // Datos corruptos: ignoramos
      continue;
    }

    // Recortamos al rango global
    final intervalStartClamped = intervalStart.isBefore(rangeStartDateTime)
        ? rangeStartDateTime
        : intervalStart;
    final intervalEndClamped =
        intervalEndRaw.isAfter(rangeEndDateTime) ? rangeEndDateTime : intervalEndRaw;

    if (intervalEndClamped.isBefore(intervalStartClamped)) {
      // Fuera del rango
      continue;
    }

    // Partimos el intervalo por días (por si cruza medianoche)
    DateTime cursor = intervalStartClamped;
    while (!cursor.isAfter(intervalEndClamped)) {
      final day = _dateOnly(cursor);
      final endOfThisDay = _endOfDay(day);
      final chunkEnd =
          intervalEndClamped.isBefore(endOfThisDay) ? intervalEndClamped : endOfThisDay;

      final chunk = chunkEnd.difference(cursor);
      if (chunk.isNegative) break;

      workedPerDay[day] = (workedPerDay[day] ?? Duration.zero) + chunk;

      cursor = chunkEnd.add(const Duration(milliseconds: 1));
    }
  }

  // 2) Horas esperadas por día según las reglas recurrentes.
  // Un turno con end <= start cruza medianoche (p.ej. 22:00 → 06:00): termina
  // al día siguiente y sus horas se reparten entre los días reales, igual que
  // las trabajadas. Por eso se evalúa también el día anterior a `fromDate`:
  // su tramo de madrugada cae dentro del rango.
  final Map<DateTime, Duration> expectedPerDay = {};
  DateTime dayCursor = fromDate.subtract(const Duration(days: 1));
  while (!dayCursor.isAfter(toDate)) {
    for (final rule in rules) {
      if (!rule.matchesDate(dayCursor)) continue;

      final startDt = _onDate(rule.startTime, dayCursor);
      var endDt = _onDate(rule.endTime, dayCursor);
      if (!endDt.isAfter(startDt)) {
        // Turno nocturno: termina al día siguiente.
        endDt = endDt.add(const Duration(days: 1));
      }

      // Recortamos al rango global
      final startClamped =
          startDt.isBefore(rangeStartDateTime) ? rangeStartDateTime : startDt;
      final endClamped =
          endDt.isAfter(rangeEndDateTime) ? rangeEndDateTime : endDt;
      if (!endClamped.isAfter(startClamped)) continue;

      // Partimos el intervalo por días (por si cruza medianoche)
      DateTime cursor = startClamped;
      while (cursor.isBefore(endClamped)) {
        final day = _dateOnly(cursor);
        final endOfThisDay = _endOfDay(day);
        final chunkEnd =
            endClamped.isBefore(endOfThisDay) ? endClamped : endOfThisDay;

        final chunk = chunkEnd.difference(cursor);
        if (chunk <= Duration.zero) break;

        expectedPerDay[day] = (expectedPerDay[day] ?? Duration.zero) + chunk;

        cursor = chunkEnd.add(const Duration(milliseconds: 1));
      }
    }

    dayCursor = dayCursor.add(const Duration(days: 1));
  }

  // 3) Totales
  final totalWorked = workedPerDay.values.fold<Duration>(
    Duration.zero,
    (prev, d) => prev + d,
  );
  final totalExpected = expectedPerDay.values.fold<Duration>(
    Duration.zero,
    (prev, d) => prev + d,
  );

  return WorkHoursSummary(
    totalWorked: totalWorked,
    totalExpected: totalExpected,
    difference: totalWorked - totalExpected,
    from: fromDate,
    to: toDate,
    workedPerDay: workedPerDay,
    expectedPerDay: expectedPerDay,
  );
}