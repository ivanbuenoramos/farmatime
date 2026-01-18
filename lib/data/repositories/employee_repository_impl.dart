import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/employee_repository.dart';
import 'package:firebase_core/firebase_core.dart';

class EmployeeRepositoryImpl implements EmployeeRepository {
  
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseFunctions functions = FirebaseFunctions.instanceFor(
    app: Firebase.app(),
    region: 'europe-west1',
  );

  @override
  Future<Result<EmployeeModel?>> createEmployee(EmployeeModel employee) async {
    try {
      final callable = functions.httpsCallable('createEmployeeAccount');

      final payload = employee.toJson();

      final resp = await callable.call(payload);
      final data = (resp.data as Map?) ?? {};
      final uid = data['uid']?.toString();

      if (uid == null || uid.isEmpty) {
        return Result(success: false, data: null, errorCode: 'uid-null');
      }

      final created = employee.copyWith(
        uid: uid,
      );

      return Result(success: true, data: created);
    } catch (e) {
      print(e);
      return Result(success: false, data: null, errorCode: e.toString());
    }
  }

  @override
  Future<Result<EmployeeModel?>> updateEmployee(EmployeeModel employee) async {
    try {
      await firestore.collection('employees').doc(employee.uid).update(employee.toJson());
      return Result(success: true, data: employee);
    } catch (e) {
      print(e);
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
      print(e);
      return Result(success: false, data: null, errorCode: e.toString());
    }
  }

  @override
  Future<Result<List<EmployeeModel>>> getEmployeesByCompanyId({
    required String companyId,
    bool? includeDeleted = false,
  }) async {
    try {
      if (includeDeleted == true) {
        final query = await firestore
            .collection('employees')
            .where('companyId', isEqualTo: companyId)
            .get();

        final employees = query.docs.map((doc) => EmployeeModel.fromJson(doc.data())).toList();
        return Result(success: true, data: employees);
      } else {
        final query = await firestore
          .collection('employees')
          .where('accountStatus', isNotEqualTo: 'deleted')
          .where('companyId', isEqualTo: companyId)
          .get();

        final employees = query.docs.map((doc) => EmployeeModel.fromJson(doc.data())).toList();
      return Result(success: true, data: employees);
      }
    } catch (e) {
      print(e);
      return Result(success: false, data: [], errorCode: e.toString());
    }
  }

  @override
  Stream<List<EmployeeModel>> streamEmployeesByCompanyId(String companyId) {
    return firestore
    .collection('employees')
    .where('companyId', isEqualTo: companyId)
    .snapshots()
    .map((snap) {
      return snap.docs.map((d) {
        final data = d.data();

        // Ajusta si tu fromJson ya mete el uid, si no:
        final employee = EmployeeModel.fromJson(data);

        // Si tu modelo necesita uid del doc:
        // return employee.copyWith(uid: d.id);

        // Si fromJson ya trae uid, devuelve tal cual:
        // (yo prefiero forzar uid del doc siempre)
        try {
          return employee.copyWith(uid: d.id);
        } catch (_) {
          // si no tienes copyWith(uid:), al menos asegúrate en tu model
          // de que uid venga en el json o modifica el model
          return employee;
        }
      }).toList();
    });
  }

}