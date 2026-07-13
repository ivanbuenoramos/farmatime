import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/schedule/day_entry.dart';
import 'package:farmatime/domain/repositories/employee_schedule_repository.dart';

class GetAssignedDaysInYearUseCase {
  final EmployeeScheduleRepository repo;
  GetAssignedDaysInYearUseCase(this.repo);

  /// Devuelve el conjunto de fechas (yyyy-MM-dd) marcadas con [type] durante
  /// el año natural [year] para el empleado dado.
  Future<Result<Set<String>>> call({
    required String companyId,
    required String employeeId,
    required int year,
    required DayType type,
  }) =>
      repo.getAssignedDaysOfTypeInYear(
        companyId: companyId,
        employeeId: employeeId,
        year: year,
        type: type,
      );
}
