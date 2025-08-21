import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/schedule/day_entry.dart';
import 'package:farmatime/domain/repositories/employee_schedule_repository.dart';

class UpsertEmployeeYearScheduleUseCase {
  final EmployeeScheduleRepository repo;
  UpsertEmployeeYearScheduleUseCase(this.repo);

  Future<Result<bool>> call({
    required String companyId,
    required String employeeId,
    required int year,
    required Map<String, DayEntry> entries,
  }) => repo.upsertYear(companyId: companyId, employeeId: employeeId, year: year, entries: entries);
}