import 'package:farmatime/presentation/presentation.dart';
import 'package:get/get.dart';

import 'package:farmatime/domain/usecases/firebase_auth/send_password_reset_email_usecase.dart';



class ForgotPasswordBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SendPasswordResetEmailUseCase>(
      () => SendPasswordResetEmailUseCase(Get.find()), // FirebaseAuthRepository ya registrado
    );
    Get.lazyPut<ForgotPasswordController>(
      () => ForgotPasswordController(Get.find<SendPasswordResetEmailUseCase>()),
    );
  }
}