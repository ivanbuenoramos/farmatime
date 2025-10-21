import 'package:farmatime/data/repositories/firebase_auth_repository_impl.dart';
import 'package:farmatime/domain/repositories/firebase_auth_repository.dart';
import 'package:farmatime/domain/usecases/firebase_auth/log_out_usecase.dart';
import 'package:farmatime/presentation/presentation.dart';
import 'package:get/get.dart';

import 'package:farmatime/domain/repositories/company_repository.dart';
import 'package:farmatime/data/repositories/company_repository_impl.dart';
import 'package:farmatime/domain/usecases/company/update_company_usecase.dart';
import 'package:farmatime/domain/repositories/firebase_storage_repository.dart';
import 'package:farmatime/data/repositories/firebase_storage_repository_impl.dart';
import 'package:farmatime/domain/usecases/firebase_storage/upload_file_usecase.dart';



class CompanyAccountBinding extends Bindings {
  @override
  void dependencies() {

    Get.lazyPut<FirebaseAuthRepository>(() => FirebaseAuthRepositoryImpl());

    Get.lazyPut<FirebaseStorageRepository>(() => FirebaseStorageRepositoryImpl());

    Get.lazyPut<CompanyRepository>(() => CompanyRepositoryImpl());

    Get.lazyPut<UpdateCompanyUsecase>(
      () => UpdateCompanyUsecase(Get.find<CompanyRepository>()),
    );

    Get.lazyPut<UploadFileUseCase>(
      () => UploadFileUseCase(Get.find<FirebaseStorageRepository>()),
    );

    Get.lazyPut<LogOutUseCase>(
      () => LogOutUseCase(Get.find<FirebaseAuthRepository>()),
    );

    Get.lazyPut(() => CompanyAccountController(
      updateCompanyUseCase: Get.find<UpdateCompanyUsecase>(),
      uploadFileUseCase: Get.find<UploadFileUseCase>(),
      logOutUseCase: Get.find<LogOutUseCase>(),
    ));
  }
}
