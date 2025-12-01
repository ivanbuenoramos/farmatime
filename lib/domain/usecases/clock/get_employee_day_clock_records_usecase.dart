import 'package:farmatime/data/models/clock_in_out_model.dart';
import 'package:farmatime/domain/repositories/clock_repository.dart';

class GetEmployeeDayClockRecordsUseCase {
  final ClockRepository repository;

  GetEmployeeDayClockRecordsUseCase(this.repository);

  Future<List<ClockInOutModel>> call({
    required String companyId,
    required String employeeId,
    required DateTime day,
  }) {
    return repository.getClockRecordsForEmployeeDay(
      companyId: companyId,
      employeeId: employeeId,
      day: day,
    );
  }
}