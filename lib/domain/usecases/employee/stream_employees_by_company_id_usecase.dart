import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/domain/repositories/employee_repository.dart';

class StreamEmployeesByCompanyIdUseCase {
  StreamEmployeesByCompanyIdUseCase(this._repo);

  final EmployeeRepository _repo;

  Stream<List<EmployeeModel>> call({required String companyId}) {
    return _repo.streamEmployeesByCompanyId(companyId);
  }
}