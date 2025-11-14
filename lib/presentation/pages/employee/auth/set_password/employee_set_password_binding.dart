import 'package:farmatime/domain/repositories/employee_repository.dart';
import 'package:farmatime/domain/usecases/employee/update_employee_usecase.dart';
import 'package:farmatime/presentation/presentation.dart';
import 'package:farmatime/domain/repositories/firebase_auth_repository.dart';
import 'package:farmatime/domain/usecases/firebase_auth/change_password_usecase.dart';

import 'package:get/get.dart';



class EmployeeSetPasswordBinding extends Bindings {
  @override
  void dependencies() {
    
    Get.lazyPut<ChangePasswordUsecase>(() => ChangePasswordUsecase(Get.find<FirebaseAuthRepository>()));

    Get.lazyPut<UpdateEmployeeUseCase>(() => UpdateEmployeeUseCase(Get.find<EmployeeRepository>()));

    Get.lazyPut<EmployeeSetPasswordController>(
      () => EmployeeSetPasswordController(
        changePasswordUseCase: Get.find<ChangePasswordUsecase>(),
        updateEmployeeUseCase: Get.find<UpdateEmployeeUseCase>(),
      )
    );
  }
}