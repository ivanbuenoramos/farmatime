import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/schedule/recurring_shift_rule.dart';
import 'package:farmatime/domain/repositories/employee_schedule_repository.dart';

class ListRecurringRulesUseCase {
  final EmployeeScheduleRepository repo;
  ListRecurringRulesUseCase(this.repo);

  Future<Result<List<RecurringShiftRule>>> call({
    required String companyId,
    required String employeeId,
  }) => repo.listRecurringRules(companyId: companyId, employeeId: employeeId);
}

