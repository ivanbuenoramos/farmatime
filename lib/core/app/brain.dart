import 'dart:convert';

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

  void updateEmployeeData(EmployeeModel newEmployee) {
    employee.value = newEmployee;
    GetStorage().write('employee', json.encode(newEmployee.toJson()));
  }

  void updateCompanyData(EmployeeModel newCompany) {
    employee.value = newCompany;
    GetStorage().write('company', json.encode(newCompany.toJson()));
  }

  // Clear user data from memory and local storage
  void clearSession() {
    employee = Rx<EmployeeModel?>(null);
    company = Rx<CompanyModel?>(null);
    Future.delayed(Duration.zero, () => Get.forceAppUpdate());
    GetStorage().remove('employee');
    GetStorage().remove('company');
  }
}