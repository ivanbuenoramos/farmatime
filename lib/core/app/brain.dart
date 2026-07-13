import 'dart:convert';

import 'package:farmatime/core/services/push_notification_service.dart';
import 'package:farmatime/data/models/company_model.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';



class Brain {

  static final Brain _instance = Brain._internal();
  factory Brain() => _instance;

  Brain._internal();

  // Observable for user data
  Rx<EmployeeModel?> employee = Rx<EmployeeModel?>(null);
  Rx<CompanyModel?> company = Rx<CompanyModel?>(null);
  RxList<EmployeeModel> companyEmployees = <EmployeeModel>[].obs;

  Future<void> loadSession() async {
    final storage = GetStorage();
    final userJson = storage.read('employee');
    final companyJson = storage.read('company');

    if (userJson != null) {
      employee.value = EmployeeModel.fromJson(json.decode(userJson));
    }
    if (companyJson != null) {
      company.value = CompanyModel.fromJson(json.decode(companyJson));
    }
  }

  /// Color de avatar (ARGB) asignado a un empleado, buscado por su [uid].
  /// Mira la lista de empleados de la empresa y el empleado de sesión.
  /// Devuelve null si no se encuentra o no tiene color (la UI cae al primario).
  int? avatarColorForUid(String? uid) {
    if (uid == null || uid.isEmpty) return null;
    for (final e in companyEmployees) {
      if (e.uid == uid) return e.avatarColor;
    }
    if (employee.value?.uid == uid) return employee.value?.avatarColor;
    return null;
  }

  void updateEmployeeData(EmployeeModel newEmployee) {
    employee.value = newEmployee;
    GetStorage().write('employee', json.encode(newEmployee.toJson()));
  }

  void updateCompanyData(CompanyModel newCompany) {
    company.value = newCompany;
    GetStorage().write('company', json.encode(newCompany.toJson()));
  }

  // Clear user data from memory and local storage
  void clearSession() {
    // Borra el token FCM de este dispositivo para no seguir recibiendo
    // notificaciones de la cuenta de la que se sale (best-effort, no bloquea).
    if (Get.isRegistered<PushNotificationService>()) {
      Get.find<PushNotificationService>().unregisterTokenForCurrentUser();
    }
    employee = Rx<EmployeeModel?>(null);
    company = Rx<CompanyModel?>(null);
    Future.delayed(Duration.zero, () => Get.forceAppUpdate());
    GetStorage().remove('employee');
    GetStorage().remove('company');
  }
}