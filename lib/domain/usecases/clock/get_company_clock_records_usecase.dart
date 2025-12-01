import 'package:farmatime/data/models/clock_in_out_model.dart';
import 'package:farmatime/domain/repositories/clock_repository.dart';

class GetCompanyClockRecordsUseCase {
  final ClockRepository repository;

  GetCompanyClockRecordsUseCase(this.repository);

  Future<List<ClockInOutModel>> call({
    required String companyId,
    required DateTime from,
    required DateTime to,
    String? employeeId,
  }) {
    return repository.getClockRecords(
      companyId: companyId,
      from: from,
      to: to,
      employeeId: employeeId,
    );
  }
}