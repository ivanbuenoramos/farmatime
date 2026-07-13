import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/employee_shift_model.dart';
import 'package:farmatime/data/models/schedule/day_entry.dart';
import 'package:farmatime/data/models/schedule/recurring_shift_rule.dart';
import 'package:farmatime/data/models/schedule/schedule_day_modelo.dart';

abstract class EmployeeScheduleRepository {
  // ── Overrides: MES ─────────────────────────────────────────────
  Future<Result<Map<String, DayEntry>>> getMonth({
    required String companyId,
    required String employeeId,
    required int year,
    required int month, // 1..12
  });

  Future<Result<bool>> upsertMonth({
    required String companyId,
    required String employeeId,
    required int year,
    required int month, // 1..12
    required Map<String, DayEntry> entries, // yyyy-MM-dd -> DayEntry
  });

  // ── Overrides: CRUD POR DÍA ────────────────────────────────────
  Future<Result<ScheduleDayModel?>> getDayOverride({
    required String companyId,
    required String employeeId,
    required String date, // yyyy-MM-dd
  });

  Future<Result<bool>> upsertDayOverride({
    required ScheduleDayModel day,
  });

  Future<Result<bool>> deleteDayOverride({
    required String companyId,
    required String employeeId,
    required String date, // yyyy-MM-dd
  });

  // ── Reglas recurrentes ─────────────────────────────────────────
  Future<Result<List<RecurringShiftRule>>> listRecurringRules({
    required String companyId,
    required String employeeId,
  });

  Future<Result<String>> upsertRecurringRule({
    required String companyId,
    required String employeeId,
    required RecurringShiftRule rule,
  });

  Future<Result<bool>> deleteRecurringRule({
    required String companyId,
    required String employeeId,
    required String ruleId,
  });

  // ── Expected shifts (optimizado) ────────────────────────────────
  Future<Result<Map<String, ExpectedShiftModel?>>> getExpectedShiftsForDay({
    required String companyId,
    required List<String> employeeIds,
    required DateTime dayDate,
    String? dayKey, // yyyy-MM-dd
  });

  /// Cuenta los días marcados (overrides) de un tipo concreto durante un año
  /// natural completo. Incluye tanto los días marcados manualmente por la
  /// empresa como los escritos al aprobar una solicitud (ambos viven en
  /// employee_schedule_months). Devuelve además el detalle por fecha
  /// (yyyy-MM-dd) para poder excluir días concretos al re-evaluar.
  Future<Result<Set<String>>> getAssignedDaysOfTypeInYear({
    required String companyId,
    required String employeeId,
    required int year,
    required DayType type,
  });

  Stream<Map<String, DayEntry>> streamMonth({
    required String companyId,
    required String employeeId,
    required int year,
    required int month,
  });

  Stream<List<RecurringShiftRule>> streamRecurringRules({
    required String companyId,
    required String employeeId,
  });
}