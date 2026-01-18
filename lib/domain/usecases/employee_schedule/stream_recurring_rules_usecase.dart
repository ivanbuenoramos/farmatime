import 'package:farmatime/data/models/schedule/recurring_shift_rule.dart';
import 'package:farmatime/domain/repositories/employee_schedule_repository.dart';

class StreamRecurringRulesUseCase {
  StreamRecurringRulesUseCase(this._repo);
  final EmployeeScheduleRepository _repo;

  Stream<List<RecurringShiftRule>> call({
    required String companyId,
    required String employeeId,
  }) {
    return _repo.streamRecurringRules(
      companyId: companyId,
      employeeId: employeeId,
    );
  }
}