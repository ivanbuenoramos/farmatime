import 'package:farmatime/data/models/schedule/time_off_model.dart';
import 'package:farmatime/domain/repositories/time_off_repository.dart';

class StreamTimeOffByEmployeeUseCase {
  final TimeOffRepository repo;
  StreamTimeOffByEmployeeUseCase(this.repo);

  Stream<List<TimeOffModel>> call({
    required String companyId,
    required String employeeId,
  }) =>
      repo.streamByEmployee(companyId: companyId, employeeId: employeeId);
}
