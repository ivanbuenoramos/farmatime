import 'package:farmatime/data/repositories/company_repository_impl.dart';
import 'package:farmatime/data/repositories/firebase_auth_repository_impl.dart';
import 'package:farmatime/domain/repositories/company_repository.dart';
import 'package:farmatime/domain/repositories/firebase_auth_repository.dart';
import 'package:farmatime/domain/usecases/company/get_company_by_id_usecase.dart';
import 'package:farmatime/domain/usecases/firebase_auth/sign_in_with_email_usecase.dart';
import 'package:get/get.dart';

import 'package:farmatime/presentation/pages/company/auth/sign_in/company_auth_sign_in_controller.dart';



class CompanyAuthSignInBinding extends Bindings {
  @override
  void dependencies() {

    Get.lazyPut<FirebaseAuthRepository>(() => FirebaseAuthRepositoryImpl());
    
    Get.lazyPut<CompanyRepository>(() => CompanyRepositoryImpl());

    Get.lazyPut<SignInWithEmailUseCase>(
      () => SignInWithEmailUseCase(Get.find<FirebaseAuthRepository>()),
    );

    Get.lazyPut<GetCompanyByIdUseCase>(
      () => GetCompanyByIdUseCase(Get.find<CompanyRepository>()),
    );
    
    Get.lazyPut<CompanyAuthSignInController>(() => CompanyAuthSignInController(
      signInWithEmailUseCase: Get.find<SignInWithEmailUseCase>(),
      getCompanyByIdUseCase: Get.find<GetCompanyByIdUseCase>(),
    ));
  }
}
