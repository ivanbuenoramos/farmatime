// lib/domain/usecases/clock/stream_company_clock_records_usecase.dart
import 'package:farmatime/data/models/clock_in_out_model.dart';
import 'package:farmatime/domain/repositories/clock_repository.dart';

class StreamCompanyClockRecordsUseCase {
  StreamCompanyClockRecordsUseCase(this._repo);
  final ClockRepository _repo;

  Stream<List<ClockInOutModel>> call({
    required String companyId,
    required DateTime from,
    required DateTime to,
    String? employeeId,
  }) {
    return _repo.streamClockRecords(
      companyId: companyId,
      from: from,
      to: to,
      employeeId: employeeId,
    );
  }
}