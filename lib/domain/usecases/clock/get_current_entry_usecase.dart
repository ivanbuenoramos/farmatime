import 'package:farmatime/data/models/clock_in_out_model.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/clock_repository.dart';

class GetCurrentEntryUseCase {
  final ClockRepository repository;

  GetCurrentEntryUseCase(this.repository);

  Future<Result<ClockInOutModel?>> call(String employeeId) {
    return repository.getCurrentEntry(employeeId);
  }
}
