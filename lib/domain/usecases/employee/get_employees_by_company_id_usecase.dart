import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/domain/repositories/employee_repository.dart';

class GetEmployeesByCompanyIdUseCase {
  final EmployeeRepository repository;

  GetEmployeesByCompanyIdUseCase(this.repository);

  Future<Result<List<EmployeeModel>>> call(String companyId) {
    return repository.getEmployeesByCompanyId(companyId);
  }
}
