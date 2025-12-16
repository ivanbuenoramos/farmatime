import 'package:farmatime/data/repositories/employee_repository_impl.dart';
import 'package:farmatime/domain/repositories/employee_repository.dart';
import 'package:get/get.dart';

import 'package:farmatime/domain/usecases/employee/update_employee_usecase.dart';
import 'delete_employee_controller.dart';

class DeleteEmployeeBinding extends Bindings {
  @override
  void dependencies() {

    Get.lazyPut<EmployeeRepository>(() => EmployeeRepositoryImpl());
    
    Get.lazyPut<UpdateEmployeeUseCase>(
      () => UpdateEmployeeUseCase(Get.find<EmployeeRepository>()),
    );
    
    Get.put<DeleteEmployeeController>(
      DeleteEmployeeController(
        updateEmployeeUseCase: Get.find<UpdateEmployeeUseCase>(),
      ),
    );
  }
}