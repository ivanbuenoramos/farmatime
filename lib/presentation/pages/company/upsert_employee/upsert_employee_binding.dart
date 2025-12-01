import 'package:farmatime/data/repositories/firebase_storage_repository_impl.dart';
import 'package:farmatime/domain/repositories/firebase_storage_repository.dart';
import 'package:farmatime/domain/usecases/employee/update_employee_usecase.dart';
import 'package:farmatime/domain/usecases/firebase_storage/upload_file_usecase.dart';
import 'package:get/get.dart';

import 'package:farmatime/domain/repositories/employee_repository.dart';
import 'package:farmatime/data/repositories/employee_repository_impl.dart';
import 'package:farmatime/domain/usecases/employee/create_employee_usecase.dart';
import 'package:farmatime/presentation/pages/company/upsert_employee/upsert_employee_controller.dart';



class UpsertEmployeeBinding extends Bindings {
  @override
  void dependencies() {
    
    Get.lazyPut<EmployeeRepository>(() => EmployeeRepositoryImpl());
    
    Get.lazyPut<FirebaseStorageRepository>(() => FirebaseStorageRepositoryImpl());

    Get.lazyPut<CreateEmployeeUseCase>(
      () => CreateEmployeeUseCase(Get.find<EmployeeRepository>()),
    );

    Get.lazyPut<UpdateEmployeeUseCase>(
      () => UpdateEmployeeUseCase(Get.find<EmployeeRepository>()),
    );

    Get.lazyPut<UploadFileUseCase>(
      () => UploadFileUseCase(Get.find<FirebaseStorageRepository>()),
    );

    Get.lazyPut(() => UpsertEmployeeController(
      createEmployeeUseCase: Get.find<CreateEmployeeUseCase>(),
      updateEmployeeUseCase: Get.find<UpdateEmployeeUseCase>(),
      uploadFileUseCase: Get.find<UploadFileUseCase>(),

    ));
  }
}
