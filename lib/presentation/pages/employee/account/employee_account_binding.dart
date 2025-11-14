import 'package:farmatime/data/repositories/employee_repository_impl.dart';
import 'package:farmatime/data/repositories/firebase_auth_repository_impl.dart';
import 'package:farmatime/domain/repositories/employee_repository.dart';
import 'package:farmatime/domain/repositories/firebase_auth_repository.dart';
import 'package:farmatime/domain/usecases/employee/update_employee_usecase.dart';
import 'package:farmatime/domain/usecases/firebase_auth/log_out_usecase.dart';
import 'package:farmatime/presentation/presentation.dart';
import 'package:get/get.dart';

import 'package:farmatime/domain/repositories/firebase_storage_repository.dart';
import 'package:farmatime/data/repositories/firebase_storage_repository_impl.dart';
import 'package:farmatime/domain/usecases/firebase_storage/upload_file_usecase.dart';



class EmployeeAccountBinding extends Bindings {
  @override
  void dependencies() {

    Get.lazyPut<FirebaseAuthRepository>(() => FirebaseAuthRepositoryImpl());

    Get.lazyPut<FirebaseStorageRepository>(() => FirebaseStorageRepositoryImpl());

    Get.lazyPut<EmployeeRepository>(() => EmployeeRepositoryImpl());

    Get.lazyPut<UpdateEmployeeUseCase>(
      () => UpdateEmployeeUseCase(Get.find<EmployeeRepository>()),
    );

    Get.lazyPut<UploadFileUseCase>(
      () => UploadFileUseCase(Get.find<FirebaseStorageRepository>()),
    );

    Get.lazyPut<LogOutUseCase>(
      () => LogOutUseCase(Get.find<FirebaseAuthRepository>()),
    );

    Get.lazyPut(() => EmployeeAccountController(
      updateEmployeeUseCase: Get.find<UpdateEmployeeUseCase>(),
      uploadFileUseCase: Get.find<UploadFileUseCase>(),
      logOutUseCase: Get.find<LogOutUseCase>(),
    ));
  }
}
