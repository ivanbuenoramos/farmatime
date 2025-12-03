// presentation/pages/account/change_password/change_password_controller.dart
import 'package:farmatime/core/app/brain.dart';
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
    if (v == brain.employee.value!.tempPassword) return 'La nueva no puede ser igual a la actual';
    return null;
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
    final Result<void> res = await changePasswordUseCase(
      currentPassword: brain.employee.value!.tempPassword!,
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
      tempPassword: '',
      accountStatus: EmployeeAccountStatus.active,
    );

    final Result updateResult = await updateEmployeeUseCase.call(updatedEmployee);

    if (updateResult.success) {
      brain.updateEmployeeData(updatedEmployee);
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
    Get.back();


  }

  @override
  void onClose() {
    newCtrl.dispose();
    confirmCtrl.dispose();
    super.onClose();
  }
}