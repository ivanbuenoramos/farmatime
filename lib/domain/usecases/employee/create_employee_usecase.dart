import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/employee_repository.dart';

class CreateEmployeeUseCase {
  final EmployeeRepository repository;

  CreateEmployeeUseCase(this.repository);

  Future<Result<EmployeeModel?>> call(EmployeeModel employee) {
    return repository.createEmployee(employee);
  }
}
