import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/schedule/day_entry.dart';
import 'package:farmatime/domain/repositories/employee_schedule_repository.dart';

class UpsertEmployeeMonthScheduleUseCase {
  final EmployeeScheduleRepository repo;
  UpsertEmployeeMonthScheduleUseCase(this.repo);

  Future<Result<bool>> call({
    required String companyId,
    required String employeeId,
    required int year,
    required int month, // 1..12
    required Map<String, DayEntry> entries, // keys: yyyy-MM-dd (solo de ese mes)
  }) {
    return repo.upsertMonth(
      companyId: companyId,
      employeeId: employeeId,
      year: year,
      month: month,
      entries: entries,
    );
  }
}