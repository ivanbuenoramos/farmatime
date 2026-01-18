import 'package:farmatime/data/models/schedule/day_entry.dart';
import 'package:farmatime/domain/repositories/employee_schedule_repository.dart';

class StreamEmployeeMonthScheduleUseCase {
  StreamEmployeeMonthScheduleUseCase(this._repo);
  final EmployeeScheduleRepository _repo;

  Stream<Map<String, DayEntry>> call({
    required String companyId,
    required String employeeId,
    required int year,
    required int month,
  }) {
    return _repo.streamMonth(
      companyId: companyId,
      employeeId: employeeId,
      year: year,
      month: month,
    );
  }
}