// presentation/pages/account/change_password/change_password_controller.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/core/services/push_notification_service.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/domain/usecases/employee/update_employee_usecase.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/usecases/firebase_auth/change_password_usecase.dart';
import 'package:farmatime/core/services/toast_service.dart'; // <-- importa tu ToastService

class EmployeeSetPasswordController extends GetxController {
  final ChangePasswordUsecase changePasswordUseCase;
  final UpdateEmployeeUseCase updateEmployeeUseCase;

  // Inyéctalo con Get.find() en el Binding
  final ToastService toast = ToastService();

  EmployeeSetPasswordController({
    required this.changePasswordUseCase,
    required this.updateEmployeeUseCase,
  });

  final Brain brain = Get.find<Brain>();

  final formKey = GlobalKey<FormState>();

  final newCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  final isLoading = false.obs;
  final showCurrent = false.obs;
  final showNew = false.obs;
  final showConfirm = false.obs;

  String? validateCurrent(String? v) {
    if (v == null || v.isEmpty) return 'Introduce tu contraseña actual';
    if (v.length < 6) return 'Debe tener al menos 6 caracteres';
    return null;
  }

  String? validateNew(String? v) {
    if (v == null || v.isEmpty) return 'Introduce la nueva contraseña';
    if (v.length < 6) return 'Debe tener al menos 6 caracteres';
    // Antes comparábamos contra brain.employee.value!.tempPassword (campo del
    // doc legible por compañeros). Ya no se persiste ahí; si la pass es igual a
    // la actual, Firebase Auth lo rechazará con error en submit().
    return null;
  }

  /// Lee la contraseña temporal desde la subcolección privada
  /// `employees/{uid}/private/credentials`. Solo el propio empleado tiene
  /// permiso de lectura (ver firestore.rules). Devuelve null si no existe.
  Future<String?> _readTempPassword() async {
    final uid = brain.employee.value?.uid;
    if (uid == null || uid.isEmpty) return null;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('employees')
          .doc(uid)
          .collection('private')
          .doc('credentials')
          .get();
      final data = snap.data();
      return data?['tempPassword'] as String?;
    } catch (_) {
      return null;
    }
  }

  String? validateConfirm(String? v) {
    if (v == null || v.isEmpty) return 'Confirma la nueva contraseña';
    if (v != newCtrl.text) return 'Las contraseñas no coinciden';
    return null;
  }

  Future<void> submit() async {
    if (isLoading.value) return;


    final isValid = formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    isLoading.value = true;
    if (_passwordAlreadyChanged) {
      isLoading.value = false;
      await onSuccess();
      return;
    }
    // tempPassword vive en una subcolección privada (no en el doc principal,
    // que es legible por los compañeros). La leemos solo en este momento.
    final tempPass = await _readTempPassword();
    if (tempPass == null || tempPass.isEmpty) {
      isLoading.value = false;
      // Sin credenciales temporales (p. ej. ya se restableció la contraseña
      // por email) el empleado quedaba atrapado en esta pantalla para
      // siempre: ofrecemos una salida en vez de un callejón sin salida.
      await _offerWayOut(
        'No encontramos tu contraseña temporal. Puedes restablecer la '
        'contraseña desde el correo o cerrar sesión y volver a entrar.',
      );
      return;
    }
    final Result<void> res = await changePasswordUseCase(
      currentPassword: tempPass,
      newPassword: newCtrl.text.trim(),
    );
    isLoading.value = false;

    if (res.success){
      await onSuccess();
    } else {
      // Muestra errores desde aquí
      // Prioriza códigos comunes, y para el resto usa tu parser genérico
      switch (res.errorCode) {
        case 'wrong-password':
        case 'user-mismatch':
        case 'invalid-credential':
          // La temporal guardada ya no coincide con Auth (contraseña cambiada
          // fuera de la app): sin salida el usuario se queda bloqueado.
          await _offerWayOut(
            'La contraseña temporal ya no es válida. Restablece la contraseña '
            'desde el correo o cierra sesión y vuelve a entrar.',
          );
          break;
        case 'user-not-found':
          toast.showParsedErrorCode('user-not-found');
          break;
        case 'weak-password':
          toast.showParsedErrorCode('weak-password');
          break;
        case 'requires-recent-login':
          toast.showParsedErrorCode('requires-recent-login');
          break;
        case 'time-exceeded':
          toast.showParsedErrorCode('time-exceeded');
          break;
        default:
          toast.showParsedErrorCode(res.errorCode, defaultMessage: 'No se pudo cambiar la contraseña.');
      }
    }
  }

  /// La contraseña ya está cambiada en Auth; ahora hay que marcar la cuenta
  /// como activa en Firestore. Si eso falla NO se da el cambio por terminado
  /// (antes se mostraba éxito y se navegaba igualmente, dejando la cuenta
  /// pendiente con una temporal que ya no servía).
  Future<void> onSuccess() async {
    final EmployeeModel updatedEmployee = brain.employee.value!.copyWith(
      hasTempPassword: false,
      accountStatus: EmployeeAccountStatus.active,
    );

    isLoading.value = true;
    Result? updateResult;
    try {
      // Un reintento ante fallos transitorios de red.
      for (var attempt = 0; attempt < 2; attempt++) {
        updateResult = await updateEmployeeUseCase.call(updatedEmployee);
        if (updateResult.success) break;
      }
    } finally {
      isLoading.value = false;
    }

    if (updateResult == null || !updateResult.success) {
      _passwordAlreadyChanged = true;
      toast.show(
        title: 'Contraseña cambiada, falta activar la cuenta',
        message: 'Tu nueva contraseña ya es válida, pero no pudimos activar la '
            'cuenta. Comprueba la conexión y pulsa "Guardar cambios" de nuevo.',
        type: ToastType.warning,
      );
      return;
    }

    brain.updateEmployeeData(updatedEmployee);
    if (Get.isRegistered<PushNotificationService>()) {
      await Get.find<PushNotificationService>()
          .registerTokenForUser(updatedEmployee.uid);
    }

    toast.show(
      title: 'Contraseña actualizada',
      message: 'Tu contraseña se cambió correctamente.',
      type: ToastType.success,
    );
    newCtrl.clear();
    confirmCtrl.clear();
    Get.offNamed(Routes.employeeMain);
  }

  /// true cuando Auth ya tiene la contraseña nueva pero el doc no se activó:
  /// el siguiente "Guardar cambios" solo reintenta la activación.
  bool _passwordAlreadyChanged = false;

  /// Diálogo con salidas cuando la contraseña temporal no sirve.
  Future<void> _offerWayOut(String message) async {
    await Get.dialog<void>(
      AlertDialog(
        title: const Text('No se pudo verificar tu cuenta'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              Get.toNamed(Routes.recoverPassword);
            },
            child: const Text('Restablecer por correo'),
          ),
          FilledButton(
            onPressed: () async {
              Get.back();
              brain.clearSession();
              await FirebaseAuth.instance.signOut();
              Get.offAllNamed(Routes.index);
            },
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }

  @override
  void onClose() {
    newCtrl.dispose();
    confirmCtrl.dispose();
    super.onClose();
  }
}