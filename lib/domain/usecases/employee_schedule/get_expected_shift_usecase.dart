// lib/domain/usecases/schedule/get_expected_shift_usecase.dart
import 'package:farmatime/data/models/employee_shift_model.dart';
import 'package:farmatime/domain/repositories/employee_schedule_repository.dart';

class GetExpectedShiftUseCase {
  final EmployeeScheduleRepository repo;
  GetExpectedShiftUseCase(this.repo);

  /// Devuelve mapa: employeeId -> ExpectedShiftModel? (null = no trabaja hoy)
  Future<Map<String, ExpectedShiftModel?>> call({
    required String companyId,
    required List<String> employeeIds,
    required DateTime dayDate,
  }) async {
    final res = await repo.getExpectedShiftsForDay(
      companyId: companyId,
      employeeIds: employeeIds,
      dayDate: dayDate,
    );
    if (!res.success) return {};
    return res.data;
  }
}
