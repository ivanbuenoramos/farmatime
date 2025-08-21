import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/employee_schedule_repository.dart';

class DeleteRecurringRuleUseCase {
  final EmployeeScheduleRepository repo;
  DeleteRecurringRuleUseCase(this.repo);

  Future<Result<bool>> call({
    required String companyId,
    required String employeeId,
    required String ruleId,
  }) => repo.deleteRecurringRule(companyId: companyId, employeeId: employeeId, ruleId: ruleId);
}