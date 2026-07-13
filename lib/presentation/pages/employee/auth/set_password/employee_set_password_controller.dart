// presentation/pages/account/change_password/change_password_controller.dart
import 'package:cloud_firestore/cloud_firestore.dart';
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
    // tempPassword vive en una subcolección privada (no en el doc principal,
    // que es legible por los compañeros). La leemos solo en este momento.
    final tempPass = await _readTempPassword();
    if (tempPass == null || tempPass.isEmpty) {
      isLoading.value = false;
      toast.show(
        title: 'No se pudo verificar tu cuenta',
        message: 'Vuelve a iniciar sesión e inténtalo de nuevo.',
        type: ToastType.error,
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
          toast.show(
            title: 'Error de autenticación',
            message: 'La contraseña actual no es correcta.',
            type: ToastType.error,
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

  Future<void> onSuccess() async {

    final EmployeeModel updatedEmployee = brain.employee.value!.copyWith(
      hasTempPassword: false,
      accountStatus: EmployeeAccountStatus.active,
    );

    final Result updateResult = await updateEmployeeUseCase.call(updatedEmployee);

    if (updateResult.success) {
      brain.updateEmployeeData(updatedEmployee);
      if (Get.isRegistered<PushNotificationService>()) {
        await Get.find<PushNotificationService>()
            .registerTokenForUser(updatedEmployee.uid);
      }
    } else {
      toast.showParsedErrorCode(
        updateResult.errorCode,
        defaultMessage: 'No se pudo actualizar el estado de la contraseña temporal.',
      );
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

  @override
  void onClose() {
    newCtrl.dispose();
    confirmCtrl.dispose();
    super.onClose();
  }
}