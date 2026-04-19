import 'package:get/get.dart';

import 'package:farmatime/domain/repositories/company_repository.dart';
import 'package:farmatime/data/repositories/company_repository_impl.dart';
import 'package:farmatime/domain/repositories/employee_repository.dart';
import 'package:farmatime/data/repositories/employee_repository_impl.dart';
import 'package:farmatime/domain/repositories/firebase_auth_repository.dart';
import 'package:farmatime/data/repositories/firebase_auth_repository_impl.dart';
import 'package:farmatime/domain/usecases/company/get_company_by_id_usecase.dart';
import 'package:farmatime/domain/usecases/employee/get_employee_by_id_usecase.dart';
import 'package:farmatime/domain/usecases/employee/get_employees_by_company_id_usecase.dart';
import 'package:farmatime/domain/usecases/firebase_auth/sign_in_with_email_usecase.dart';
import 'package:farmatime/presentation/pages/employee/auth/sign_in/employe_auth_sign_in_controller.dart';



class EmployeeAuthSignInBinding extends Bindings {
  @override
  void dependencies() {

    Get.lazyPut<FirebaseAuthRepository>(() => FirebaseAuthRepositoryImpl());

    Get.lazyPut<CompanyRepository>(() => CompanyRepositoryImpl());

    Get.lazyPut<EmployeeRepository>(() => EmployeeRepositoryImpl());

    Get.lazyPut<SignInWithEmailUseCase>(
      () => SignInWithEmailUseCase(Get.find<FirebaseAuthRepository>()),
    );

    Get.lazyPut<GetCompanyByIdUseCase>(
      () => GetCompanyByIdUseCase(Get.find<CompanyRepository>()),
    );

    Get.lazyPut<GetEmployeeByIdUseCase>(
      () => GetEmployeeByIdUseCase(Get.find<EmployeeRepository>()),
    );

    Get.lazyPut<GetEmployeesByCompanyIdUseCase>(
      () => GetEmployeesByCompanyIdUseCase(Get.find<EmployeeRepository>()),
    );

    Get.lazyPut<EmployeeAuthSignInController>(() => EmployeeAuthSignInController(
        signInWithEmailUseCase: Get.find(),
        getEmployeeByIdUseCase: Get.find(),
        getCompanyByIdUseCase: Get.find(),
        getEmployeesByCompanyIdUseCase: Get.find(),
      ),
    );
  }
}
