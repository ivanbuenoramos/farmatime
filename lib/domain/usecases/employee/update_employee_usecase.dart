import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/employee_repository.dart';

class UpdateEmployeeUseCase {
  final EmployeeRepository repository;

  UpdateEmployeeUseCase(this.repository);

  Future<Result<EmployeeModel?>> call(EmployeeModel employee) {
    return repository.updateEmployee(employee);
  }
}
