import 'package:get/get.dart';

import 'select_employee_to_remove_controller.dart';
import 'package:farmatime/domain/repositories/employee_repository.dart';
import 'package:farmatime/data/repositories/employee_repository_impl.dart';
import 'package:farmatime/domain/usecases/employee/update_employee_usecase.dart';
import 'package:farmatime/domain/usecases/employee/get_employees_by_company_id_usecase.dart';



class SelectEmployeeToRemoveBinding extends Bindings {
  @override
  void dependencies() {

    Get.lazyPut<EmployeeRepository>(() => EmployeeRepositoryImpl());

    Get.lazyPut<GetEmployeesByCompanyIdUseCase>(
      () => GetEmployeesByCompanyIdUseCase(Get.find<EmployeeRepository>()),
    );

    Get.lazyPut<UpdateEmployeeUseCase>(
      () => UpdateEmployeeUseCase(Get.find<EmployeeRepository>()),
    );

    Get.put<SelectEmployeeToRemoveController>(
      SelectEmployeeToRemoveController(
        getEmployeesByCompanyIdUseCase: Get.find<GetEmployeesByCompanyIdUseCase>(),
        updateEmployeeUseCase: Get.find<UpdateEmployeeUseCase>(),
      ),
    );
  }
}