import 'package:farmatime/data/models/employee_shift_model.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/employee_schedule_repository.dart';

class GetExpectedShiftsForDayUseCase {
  final EmployeeScheduleRepository repo;
  GetExpectedShiftsForDayUseCase(this.repo);

  Future<Result<Map<String, ExpectedShiftModel?>>> call({
    required String companyId,
    required List<String> employeeIds,
    required DateTime dayDate,
    String? dayKey, // yyyy-MM-dd (opcional)
  }) {
    return repo.getExpectedShiftsForDay(
      companyId: companyId,
      employeeIds: employeeIds,
      dayDate: dayDate,
      dayKey: dayKey,
    );
  }
}