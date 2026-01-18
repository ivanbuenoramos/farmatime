import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/schedule/day_entry.dart';
import 'package:farmatime/domain/repositories/employee_schedule_repository.dart';

class GetEmployeeMonthScheduleUseCase {
  final EmployeeScheduleRepository repo;
  GetEmployeeMonthScheduleUseCase(this.repo);

  Future<Result<Map<String, DayEntry>>> call({
    required String companyId,
    required String employeeId,
    required int year,
    required int month, // 1..12
  }) {
    return repo.getMonth(
      companyId: companyId,
      employeeId: employeeId,
      year: year,
      month: month,
    );
  }
}