import 'package:farmatime/data/repositories/company_repository_impl.dart';
import 'package:farmatime/data/repositories/firebase_auth_repository_impl.dart';
import 'package:farmatime/domain/repositories/company_repository.dart';
import 'package:farmatime/domain/repositories/firebase_auth_repository.dart';
import 'package:farmatime/domain/usecases/company/create_company_usecase.dart';
import 'package:farmatime/domain/usecases/firebase_auth/sign_up_with_email_usecase.dart';
import 'package:get/get.dart';

import 'package:farmatime/presentation/pages/company/auth/sign_up/company_auth_sign_up_controller.dart';



class CompanyAuthSignUpBinding extends Bindings {
  @override
  void dependencies() {

    Get.lazyPut<FirebaseAuthRepository>(() => FirebaseAuthRepositoryImpl());
    
    Get.lazyPut<CompanyRepository>(() => CompanyRepositoryImpl());

    Get.lazyPut<SignUpWithEmailUseCase>(
      () => SignUpWithEmailUseCase(Get.find<FirebaseAuthRepository>()),
    );

    Get.lazyPut<CreateCompanyUseCase>(
      () => CreateCompanyUseCase(Get.find<CompanyRepository>()),
    );

    Get.lazyPut<CompanyAuthSignUpController>(() => CompanyAuthSignUpController(
      signUpWithEmailUseCase: Get.find<SignUpWithEmailUseCase>(),
      createCompanyUseCase: Get.find<CreateCompanyUseCase>(),
    ));
  }
}
