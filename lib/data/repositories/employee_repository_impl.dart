import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/employee_repository.dart';

class EmployeeRepositoryImpl implements EmployeeRepository {
  
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  Future<Result<EmployeeModel?>> createEmployee(EmployeeModel employee) async {
    try {
      await firestore.collection('employees').doc(employee.uid).set(employee.toJson());
      return Result(success: true, data: employee);
    } catch (e) {
      return Result(success: false, data: null, errorCode: e.toString());
    }
  }

  @override
  Future<Result<EmployeeModel?>> updateEmployee(EmployeeModel employee) async {
    try {
      await firestore.collection('employees').doc(employee.uid).update(employee.toJson());
      return Result(success: true, data: employee);
    } catch (e) {
      return Result(success: false, data: null, errorCode: e.toString());
    }
  }

  @override
  Future<Result<EmployeeModel?>> getEmployeeById(String employeeId) async {
    try {
      print('Fetching employee with ID: $employeeId');
      final doc = await firestore.collection('employees').doc(employeeId).get();
      if (!doc.exists) {
        return Result(success: false, data: null, errorCode: 'not-found');
      }
      return Result(success: true, data: EmployeeModel.fromJson(doc.data()!));
    } catch (e) {
      return Result(success: false, data: null, errorCode: e.toString());
    }
  }

  @override
  Future<Result<List<EmployeeModel>>> getEmployeesByCompanyId(String companyId) async {
    try {
      final query = await firestore
          .collection('employees')
          .where('companyId', isEqualTo: companyId)
          .get();

      final employees = query.docs.map((doc) => EmployeeModel.fromJson(doc.data())).toList();
      return Result(success: true, data: employees);
    } catch (e) {
      return Result(success: false, data: [], errorCode: e.toString());
    }
  }
}
