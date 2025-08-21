import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/domain/repositories/employee_repository.dart';

class GetEmployeeByIdUseCase {
  final EmployeeRepository repository;

  GetEmployeeByIdUseCase(this.repository);

  Future<Result<EmployeeModel?>> call(String employeeId) {
    return repository.getEmployeeById(employeeId);
  }
}
