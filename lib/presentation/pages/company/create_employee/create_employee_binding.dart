import 'package:get/get.dart';

import 'package:farmatime/domain/repositories/employee_repository.dart';
import 'package:farmatime/data/repositories/employee_repository_impl.dart';
import 'package:farmatime/domain/usecases/employee/create_employee_usecase.dart';
import 'package:farmatime/presentation/pages/company/create_employee/create_employee_controller.dart';



class CreateEmployeeBinding extends Bindings {
  @override
  void dependencies() {
    
    Get.lazyPut<EmployeeRepository>(() => EmployeeRepositoryImpl());

    Get.lazyPut<CreateEmployeeUseCase>(
      () => CreateEmployeeUseCase(Get.find<EmployeeRepository>()),
    );
    Get.lazyPut(() => CreateEmployeeController(
      createEmployeeUseCase: Get.find<CreateEmployeeUseCase>(),
    ));
  }
}
