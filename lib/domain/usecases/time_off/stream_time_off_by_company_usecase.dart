import 'package:farmatime/data/models/schedule/time_off_model.dart';
import 'package:farmatime/domain/repositories/time_off_repository.dart';

class StreamTimeOffByCompanyUseCase {
  final TimeOffRepository repo;
  StreamTimeOffByCompanyUseCase(this.repo);

  Stream<List<TimeOffModel>> call({required String companyId}) =>
      repo.streamByCompany(companyId: companyId);
}
