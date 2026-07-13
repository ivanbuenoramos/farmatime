import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/time_off_repository.dart';

class FindTimeOffOverlapsUseCase {
  final TimeOffRepository repo;
  FindTimeOffOverlapsUseCase(this.repo);

  Future<Result<List<TimeOffOverlap>>> call({
    required String companyId,
    required String excludeEmployeeId,
    required List<String> dates,
  }) =>
      repo.findOverlaps(
        companyId: companyId,
        excludeEmployeeId: excludeEmployeeId,
        dates: dates,
      );
}
