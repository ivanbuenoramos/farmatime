import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/schedule/day_entry.dart';
import 'package:farmatime/domain/repositories/employee_schedule_repository.dart';

class GetEmployeeYearScheduleUseCase {
  final EmployeeScheduleRepository repo;
  GetEmployeeYearScheduleUseCase(this.repo);

  Future<Result<Map<String, DayEntry>>> call({
    required String companyId,
    required String employeeId,
    required int year,
  }) => repo.getYear(companyId: companyId, employeeId: employeeId, year: year);
}