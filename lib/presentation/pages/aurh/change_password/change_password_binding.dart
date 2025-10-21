import 'package:farmatime/domain/repositories/firebase_auth_repository.dart';
import 'package:farmatime/domain/usecases/firebase_auth/change_password_usecase.dart';
import 'package:farmatime/presentation/pages/aurh/change_password/change_password_controller.dart';

import 'package:get/get.dart';



class ChangePasswordBinding extends Bindings {
  @override
  void dependencies() {
    // Asegúrate de que FirebaseAuthRepository ya esté registrado en tus deps globales.
    Get.lazyPut<ChangePasswordUsecase>(() => ChangePasswordUsecase(Get.find<FirebaseAuthRepository>()));
    Get.lazyPut<ChangePasswordController>(() => ChangePasswordController(Get.find<ChangePasswordUsecase>()));
  }
}