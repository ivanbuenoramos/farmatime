import 'package:get/get.dart';

import 'package:farmatime/domain/repositories/employee_repository.dart';
import 'package:farmatime/data/repositories/employee_repository_impl.dart';
import 'package:farmatime/domain/repositories/firebase_auth_repository.dart';
import 'package:farmatime/data/repositories/firebase_auth_repository_impl.dart';
import 'package:farmatime/domain/usecases/employee/create_employee_usecase.dart';
import 'package:farmatime/domain/usecases/firebase_auth/sign_up_with_email_usecase.dart';
import 'package:farmatime/presentation/pages/company/create_employee/create_employee_controller.dart';



class CreateEmployeeBinding extends Bindings {
  @override
  void dependencies() {
    
    Get.lazyPut<FirebaseAuthRepository>(() => FirebaseAuthRepositoryImpl());
    
    Get.lazyPut<EmployeeRepository>(() => EmployeeRepositoryImpl());

    Get.lazyPut<SignUpWithEmailUseCase>(
      () => SignUpWithEmailUseCase(Get.find<FirebaseAuthRepository>()),
    );

    Get.lazyPut<CreateEmployeeUseCase>(
      () => CreateEmployeeUseCase(Get.find<EmployeeRepository>()),
    );
    Get.lazyPut(() => CreateEmployeeController(
      createEmployeeUseCase: Get.find<CreateEmployeeUseCase>(),
      signUpWithEmailUseCase: Get.find<SignUpWithEmailUseCase>(),
    ));
  }
}
