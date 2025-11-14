import 'package:farmatime/data/repositories/firebase_auth_repository_impl.dart';
import 'package:farmatime/domain/repositories/firebase_auth_repository.dart';
import 'package:farmatime/domain/usecases/firebase_auth/log_out_usecase.dart';
import 'package:get/get.dart';

import 'verify_email_controller.dart';
import 'package:farmatime/domain/repositories/company_repository.dart';
import 'package:farmatime/data/repositories/company_repository_impl.dart';
import 'package:farmatime/domain/usecases/company/update_company_usecase.dart';



class VerifyEmailBinding extends Bindings {
  @override
  void dependencies() {
    
    Get.lazyPut<CompanyRepository>(() => CompanyRepositoryImpl());
    
    Get.lazyPut<FirebaseAuthRepository>(() => FirebaseAuthRepositoryImpl());

    Get.lazyPut<LogOutUseCase>(() => LogOutUseCase(
      Get.find<FirebaseAuthRepository>()
    ));

    Get.lazyPut<UpdateCompanyUsecase>(() => UpdateCompanyUsecase(
      Get.find<CompanyRepository>()
    ));

    Get.put<VerifyEmailController>(VerifyEmailController(
      updateCompanyUseCase: Get.find<UpdateCompanyUsecase>(),
      logoutUseCase: Get.find<LogOutUseCase>()
    ));
  }
}