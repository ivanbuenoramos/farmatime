import 'package:get/get.dart';

import 'package:farmatime/domain/repositories/employee_repository.dart';
import 'package:farmatime/data/repositories/employee_repository_impl.dart';
import 'package:farmatime/domain/repositories/firebase_auth_repository.dart';
import 'package:farmatime/data/repositories/firebase_auth_repository_impl.dart';
import 'package:farmatime/domain/usecases/employee/get_employee_by_id_usecase.dart';
import 'package:farmatime/domain/usecases/firebase_auth/sign_in_with_email_usecase.dart';
import 'package:farmatime/presentation/pages/employee/auth/sign_in/employe_auth_sign_in_controller.dart';



class EmployeeAuthSignInBinding extends Bindings {
  @override
  void dependencies() {

    Get.lazyPut<FirebaseAuthRepository>(() => FirebaseAuthRepositoryImpl());
    
    Get.lazyPut<EmployeeRepository>(() => EmployeeRepositoryImpl());

    Get.lazyPut<SignInWithEmailUseCase>(
      () => SignInWithEmailUseCase(Get.find<FirebaseAuthRepository>()),
    );

    Get.lazyPut<GetEmployeeByIdUseCase>(
      () => GetEmployeeByIdUseCase(Get.find<EmployeeRepository>()),
    );
    
    Get.lazyPut<EmployeeAuthSignInController>(() => EmployeeAuthSignInController(
        signInWithEmailUseCase: Get.find(),
        getEmployeeByIdUseCase: Get.find(),
      ),
    );
  }
}
