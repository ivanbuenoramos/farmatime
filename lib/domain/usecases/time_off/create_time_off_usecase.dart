import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/schedule/time_off_model.dart';
import 'package:farmatime/domain/repositories/time_off_repository.dart';

class CreateTimeOffUseCase {
  final TimeOffRepository repo;
  CreateTimeOffUseCase(this.repo);

  Future<Result<String>> call(TimeOffModel request) => repo.create(request);
}
