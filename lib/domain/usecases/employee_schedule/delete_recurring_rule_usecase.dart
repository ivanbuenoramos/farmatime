import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/employee_schedule_repository.dart';

class DeleteRecurringShiftRuleUseCase {
  final EmployeeScheduleRepository repo;
  DeleteRecurringShiftRuleUseCase(this.repo);

  Future<Result<bool>> call({
    required String companyId,
    required String employeeId,
    required String ruleId,
  }) {
    return repo.deleteRecurringRule(
      companyId: companyId,
      employeeId: employeeId,
      ruleId: ruleId,
    );
  }
}