import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/usecases/firebase_auth/send_password_reset_email_usecase.dart';



class ForgotPasswordController extends GetxController {
  final SendPasswordResetEmailUseCase _sendPasswordResetEmailUseCase;

  ForgotPasswordController(this._sendPasswordResetEmailUseCase);

  final TextEditingController emailCtrl = TextEditingController();

  final RxBool submitting = false.obs;
  final RxnString emailError = RxnString(null);

  @override
  void onClose() {
    emailCtrl.dispose();
    super.onClose();
  }

  void onEmailChanged(String value) {
    emailError.value = _validateEmail(value);
  }

  String? _validateEmail(String value) {
    final email = value.trim();

    if (email.isEmpty) {
      return 'Introduce un correo electrónico';
    }

    const pattern =
        r"^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$";
    final regExp = RegExp(pattern);

    if (!regExp.hasMatch(email)) {
      return 'Correo electrónico no válido';
    }

    return null;
  }

  bool get canSubmit {
    final error = _validateEmail(emailCtrl.text);
    emailError.value = error;
    return error == null && !submitting.value;
  }

  Future<void> sendResetEmail() async {
    if (!canSubmit) return;

    submitting.value = true;
    final email = emailCtrl.text.trim();

    try {
      final Result<void> result =
          await _sendPasswordResetEmailUseCase(email);

      // Ajusta estos campos a tu implementación real de Result
      if (result.success) {
        Get.snackbar(
          'Correo enviado',
          'Hemos enviado un enlace para restablecer tu contraseña a $email',
          snackPosition: SnackPosition.BOTTOM,
        );
        // Si quieres volver automáticamente:
        // Get.back();
      } else {
        Get.snackbar(
          'Error',
          'No se ha podido enviar el correo',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Ha ocurrido un error inesperado',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      submitting.value = false;
    }
  }
}