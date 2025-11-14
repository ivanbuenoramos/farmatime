import 'package:get/get.dart';

import 'package:farmatime/domain/repositories/firebase_auth_repository.dart';
import 'package:farmatime/domain/usecases/firebase_auth/log_out_usecase.dart';
import 'package:farmatime/data/repositories/firebase_auth_repository_impl.dart';
import 'package:farmatime/presentation/pages/company/settings/settings_controller.dart';



class SettingsBinding extends Bindings {
  @override
  void dependencies() {

    Get.lazyPut<FirebaseAuthRepository>(() => FirebaseAuthRepositoryImpl());

    Get.lazyPut<LogOutUseCase>(
      () => LogOutUseCase(Get.find<FirebaseAuthRepository>()),
    );

    Get.lazyPut<SettingsController>(() => SettingsController(
      logOutUseCase: Get.find<LogOutUseCase>(),
    ));
  }
}