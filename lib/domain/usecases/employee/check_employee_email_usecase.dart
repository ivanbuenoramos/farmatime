import 'package:farmatime/domain/repositories/employee_repository.dart';

class CheckEmployeeEmailUseCase {
  final EmployeeRepository repository;

  CheckEmployeeEmailUseCase(this.repository);

  Future<EmailAvailability> call(String email) {
    return repository.checkEmailAvailability(email);
  }
}
