import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:toastification/toastification.dart';




class ToastService {
  
  void show({

    String? iconPath,
    required String title,
    String? message,
    required ToastType type,
    int duration = 6, // Duración en segundos
  }) {
    Color backgroundColor;
    Color textColor;
    Color primaryColor;

    switch (type) {
      case ToastType.success:
        textColor = const Color(0xff35B58D);
        backgroundColor = const Color(0xffD7F0E8);
        primaryColor = const Color(0xff35B58D);
        break;
      case ToastType.info:
        textColor = Get.theme.colorScheme.primary;
        backgroundColor = const Color(0xffEFEDFF);
        primaryColor = Get.theme.colorScheme.primary;
        break;
      case ToastType.warning:
        textColor = const Color(0xffFF9F2E);
        backgroundColor = const Color(0xffFFECD5);
        primaryColor = const Color(0xffFF9F2E);
        break;
      case ToastType.error:
        textColor = Get.theme.colorScheme.error;
        backgroundColor = const Color(0xffFDDCDC);
        primaryColor = Get.theme.colorScheme.error;
        break;
    }

    toastification.show(
      primaryColor: primaryColor,
      padding: const EdgeInsets.all(10),
      icon: SizedBox(),
      alignment: Alignment.topCenter,
      title: Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
      description: message != null ? Text(message, style: TextStyle(color: textColor, fontSize: 16)) : null,
      style: ToastificationStyle.flatColored,
      borderRadius: BorderRadius.circular(10),
      showProgressBar: false,
      foregroundColor: textColor,
      backgroundColor: backgroundColor,
      autoCloseDuration: Duration(seconds: duration),
    );
  }


  void showParsedErrorCode(String? errorCode, {String? defaultMessage}) {
    String errorTitle = '';
    String errorMessage = '';

    switch (errorCode) {
      case 'user-not-found':
        errorTitle = 'Error de autenticación';
        errorMessage = 'Correo o contraseña incorrectos';
        break;
      case 'wrong-password':
        errorTitle = 'Error de autenticación';
        errorMessage = 'Correo o contraseña incorrectos';
        break;
      case 'auth-error':
        errorTitle = 'Error de autenticación';
        errorMessage = 'Ha ocurrido un error al iniciar sesión';
        break;
      case 'network-request-failed':
        errorTitle = 'Error de conexión';
        errorMessage = 'Verifica tu conexión a internet e inténtalo de nuevo';
        break;
      case 'user-disabled':
        errorTitle = 'Usuario deshabilitado';
        errorMessage = 'Este usuario está deshabilitado';
        break;
      case 'too-many-requests':
        errorTitle = 'Demasiadas solicitudes';
        errorMessage = 'Por favor, inténtalo más tarde';
        break;
      case 'email-already-in-use':
        errorTitle = 'Correo en uso';
        errorMessage = 'El correo electrónico ya está siendo utilizado por otro usuario';
        break;
      case 'invalid-email':
        errorTitle = 'Correo inválido';
        errorMessage = 'El correo electrónico no es válido';
        break;
      case 'time-exceeded':
        errorTitle = 'Tiempo de espera excedido';
        errorMessage = 'Parece que estás teniendo problemas de conexión a internet';
        break;
      case 'credential-already-in-use':
        errorTitle = 'Teléfono inválido';
        errorMessage = 'El número de teléfono ya está en uso.';
        break;
      case 'operation-not-allowed':
        errorTitle = 'Operación no permitida';
        errorMessage = 'Esta operación no está habilitada. Contacta al administrador.';
        break;
      case 'invalid-verification-code':
        errorTitle = 'Código inválido';
        errorMessage = 'El código de verificación ingresado no es válido.';
        break;
      case 'invalid-verification-id':
        errorTitle = 'ID de verificación inválido';
        errorMessage = 'El ID de verificación proporcionado no es válido.';
        break;
      case 'expired-action-code':
        errorTitle = 'Código expirado';
        errorMessage = 'El código de acción ha expirado. Solicita uno nuevo.';
        break;
      case 'invalid-action-code':
        errorTitle = 'Código de acción inválido';
        errorMessage = 'El código de acción proporcionado no es válido.';
        break;
      case 'missing-email':
        errorTitle = 'Correo faltante';
        errorMessage = 'No se proporcionó un correo electrónico.';
        break;
      case 'missing-phone-number':
        errorTitle = 'Teléfono faltante';
        errorMessage = 'No se proporcionó un número de teléfono.';
        break;
      case 'invalid-phone-number':
        errorTitle = 'Teléfono inválido';
        errorMessage = 'El número de teléfono ingresado no es válido.';
        break;
      case 'weak-password':
        errorTitle = 'Contraseña débil';
        errorMessage = 'La contraseña debe tener al menos 6 caracteres.';
        break;
      case 'requires-recent-login':
        errorTitle = 'Inicio de sesión requerido';
        errorMessage = 'Por seguridad, vuelve a iniciar sesión e inténtalo de nuevo.';
        break;
      case 'captcha-check-failed':
        errorTitle = 'Captcha no superado';
        errorMessage = 'No se pudo validar el captcha. Inténtalo nuevamente.';
        break;
      case 'unverified-email':
        errorTitle = 'Correo no verificado';
        errorMessage = 'Por favor, verifica tu correo electrónico antes de continuar.';
        break;
      case 'invalid-credential':
        errorTitle = 'Credencial inválida';
        errorMessage = 'La credencial proporcionada no es válida.';
        break;
      default:
        errorTitle = 'Error';
        errorMessage = defaultMessage ?? 'Ha ocurrido un error inesperado.';
        break;
    }

    // toastification.show(
    //   primaryColor: Get.theme.colorScheme.error,
    //   padding: const EdgeInsets.all(10),
    //   icon: SizedBox(),
    //   alignment: Alignment.topCenter,
    //   title: Text(errorTitle, style: TextStyle(color: Get.theme.colorScheme.error, fontWeight: FontWeight.bold, fontSize: 18)),
    //   description: Text(errorMessage, style: TextStyle(color: Get.theme.colorScheme.error, fontSize: 16)),
    //   style: ToastificationStyle.flatColored,
    //   borderRadius: BorderRadius.circular(10),
    //   showProgressBar: false,
    //   foregroundColor: Get.theme.colorScheme.error,
    //   backgroundColor: const Color(0xffFDDCDC),
    //   autoCloseDuration: const Duration(seconds: 6),
    // );
  }
}

enum ToastType { success, info, warning, error }
