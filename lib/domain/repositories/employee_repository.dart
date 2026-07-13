import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/data/models/result.dart';

/// Resultado de comprobar si un email se puede usar para un nuevo empleado.
enum EmailAvailability {
  /// El correo tiene formato válido y no está en uso.
  available,

  /// El formato del correo no es válido.
  invalidFormat,

  /// Ya existe un usuario en Firebase Auth con ese correo.
  alreadyInUse,

  /// No se pudo comprobar (error de red / servidor).
  unknown,
}

abstract class EmployeeRepository {
  Future<Result<EmployeeModel?>> createEmployee(EmployeeModel employee);
  Future<Result<EmployeeModel?>> updateEmployee(EmployeeModel employee);
  Future<Result<EmployeeModel?>> getEmployeeById(String employeeId);
  Future<Result<List<EmployeeModel>>> getEmployeesByCompanyId({
    required String companyId,
    bool? includeDeleted = false,
  });

  Stream<List<EmployeeModel>> streamEmployeesByCompanyId(String companyId);

  /// Comprueba si [email] se puede usar para crear un empleado: formato
  /// correcto y que no exista ya un usuario en Firebase Auth con ese correo.
  Future<EmailAvailability> checkEmailAvailability(String email);
}
