import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:farmatime/core/services/toast_service.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/domain/usecases/employee/update_employee_usecase.dart';

class DeleteEmployeeController extends GetxController {
  final UpdateEmployeeUseCase _updateEmployeeUseCase;
  

  DeleteEmployeeController({
    required UpdateEmployeeUseCase updateEmployeeUseCase,
  }) : _updateEmployeeUseCase = updateEmployeeUseCase;

  final Rx<EmployeeModel?> employee = Rx<EmployeeModel?>(null);

  final confirmationController = TextEditingController();
  final isDeleting = false.obs;

  bool get isNameCorrect => confirmationController.text.trim() == employee.value!.name.trim();

  @override
  void onInit() {
    super.onInit();
    if (Get.arguments is! EmployeeModel) {
      Get.back();
      return;
    }
    employee.value = Get.arguments as EmployeeModel;

    //listener apra el campo de confirmación, que se cierre el teclado cuando el nombre es correcto
    confirmationController.addListener(() {
      if (isNameCorrect) {
        FocusScope.of(Get.context!).unfocus();
      }
      update();
    });


  }


  @override
  void onClose() {
    confirmationController.dispose();
    super.onClose();
  }

  Future<void> deleteEmployee() async {
    if (!isNameCorrect || isDeleting.value) return;

    isDeleting.value = true;
    try {
      final updatedEmployee = employee.value!.copyWith(
        accountStatus: EmployeeAccountStatus.deleted,
      );

      await _updateEmployeeUseCase.call(updatedEmployee);

      Get.back(result: true);
      ToastService().show(
        title: 'Empleado eliminado',
        message: 'La cuenta de ${employee.value!.name} ha sido eliminada.',
        type: ToastType.success,
      );
    } catch (e) {
      ToastService().show(
        title: 'Error',
        message: 'No se ha podido eliminar al empleado. Inténtalo de nuevo.',
        type: ToastType.error,
      );
    } finally {
      isDeleting.value = false;
    }
  }

  void onConfirmationChanged(String value) {
    update();
  }
}