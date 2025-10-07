import 'package:get/get.dart';

import 'company_employees_controller.dart';
import 'package:farmatime/domain/repositories/employee_repository.dart';
import 'package:farmatime/data/repositories/employee_repository_impl.dart';
import 'package:farmatime/domain/usecases/employee/get_employees_by_company_id_usecase.dart';



class CompanyEmployeesBinding extends Bindings {
  @override
  void dependencies() {

    Get.lazyPut<EmployeeRepository>(() => EmployeeRepositoryImpl());

    Get.lazyPut<GetEmployeesByCompanyIdUseCase>(
      () => GetEmployeesByCompanyIdUseCase(Get.find<EmployeeRepository>()),
    );
    
    Get.lazyPut<CompanyEmployeesController>(() => CompanyEmployeesController(
      getEmployeesByCompanyIdUseCase: Get.find<GetEmployeesByCompanyIdUseCase>(),
      
    ));

  }
}