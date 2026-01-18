import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/data/models/result.dart';

abstract class EmployeeRepository {
  Future<Result<EmployeeModel?>> createEmployee(EmployeeModel employee);
  Future<Result<EmployeeModel?>> updateEmployee(EmployeeModel employee);
  Future<Result<EmployeeModel?>> getEmployeeById(String employeeId);
  Future<Result<List<EmployeeModel>>> getEmployeesByCompanyId({
    required String companyId,
    bool? includeDeleted = false,
  });

  Stream<List<EmployeeModel>> streamEmployeesByCompanyId(String companyId);
  
}
