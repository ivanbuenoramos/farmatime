import 'package:farmatime/data/models/clock_in_out_model.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/clock_repository.dart';

class UpdateEntryUseCase {
  final ClockRepository repository;

  UpdateEntryUseCase(this.repository);

  Future<Result<ClockInOutModel?>> call(ClockInOutModel entry) {
    return repository.updateEntry(entry);
  }
}
