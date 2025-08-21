import 'package:farmatime/data/models/employee_shift_model.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/schedule/day_entry.dart';
import 'package:farmatime/data/models/schedule/recurring_shift_rule.dart';


abstract class EmployeeScheduleRepository {
  Future<Result<Map<String, DayEntry>>> getYear({
    required String companyId,
    required String employeeId,
    required int year,
  });

  Future<Result<bool>> upsertYear({
    required String companyId,
    required String employeeId,
    required int year,
    required Map<String, DayEntry> entries,
  });

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

  Future<Result<Map<String, ExpectedShiftModel?>>> getExpectedShiftsForDay({
    required String companyId,
    required List<String> employeeIds,
    required DateTime dayDate,
    String? dayKey, // si no viene, se calcula 'yyyy-MM-dd'
  });
}