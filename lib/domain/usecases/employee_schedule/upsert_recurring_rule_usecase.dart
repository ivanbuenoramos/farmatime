import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/schedule/recurring_shift_rule.dart';
import 'package:farmatime/domain/repositories/employee_schedule_repository.dart';

class UpsertRecurringRuleUseCase {
  final EmployeeScheduleRepository repo;
  UpsertRecurringRuleUseCase(this.repo);

  Future<Result<String>> call({
    required String companyId,
    required String employeeId,
    required RecurringShiftRule rule,
  }) => repo.upsertRecurringRule(companyId: companyId, employeeId: employeeId, rule: rule);
}