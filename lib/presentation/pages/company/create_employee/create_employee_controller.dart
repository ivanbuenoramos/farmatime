import 'package:farmatime/core/services/toast_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'package:get/get.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/domain/usecases/employee/create_employee_usecase.dart';



class CreateEmployeeController extends GetxController {
  final CreateEmployeeUseCase createEmployeeUseCase;

  CreateEmployeeController({required this.createEmployeeUseCase});

  final Brain brain = Get.find<Brain>();
  final ToastService toastService = ToastService();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final hourlyRateController = TextEditingController(text: '0');
  final vacationPer30Controller = TextEditingController(text: '2.5');
  final personalPerYearController = TextEditingController(text: '0');
  final roleOtherController = TextEditingController();

  final role = EmployeeRole.tecnico.obs;
  final workdayType = Rx<WorkdayType?>(null);

  final isLoading = false.obs;

  double _parseDouble(TextEditingController c, {double def = 0}) {
    final s = c.text.trim().replaceAll(',', '.');
    return double.tryParse(s) ?? def;
  }

  Future<void> createEmployee() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();

    if (name.isEmpty || email.isEmpty || !GetUtils.isEmail(email)) {
      toastService.show(
        title: 'Error',
        description: 'Por favor, introduce un nombre y correo válidos.',
        type: ToastType.error
      );
      return;
    }

    // Validaciones campos nuevos (cliente)
    final rate = _parseDouble(hourlyRateController);
    final vac30 = _parseDouble(vacationPer30Controller, def: 2.5);
    final personal = _parseDouble(personalPerYearController);

    if (rate < 0) {
      toastService.show(
        title: 'Error',
        description: 'El precio por hora no puede ser negativo.',
        type: ToastType.error
      );
      return;
    }
    if (vac30 < 0) {
      toastService.show(
        title: 'Error',
        description: 'Los días de vacaciones/30 días no pueden ser negativos.',
        type: ToastType.error
      );
      return;
    }
    if (personal < 0) {
      toastService.show(
        title: 'Error',
        description: 'Los días de asuntos propios/año no pueden ser negativos.',
        type: ToastType.error
      );
      return;
    }
    if (role.value == EmployeeRole.otro && roleOtherController.text.trim().isEmpty) {
      toastService.show(
        title: 'Error',
        description: 'Indica el cargo en "Otro (especificar)".',
        type: ToastType.error
      );
      return;
    }

    final companyId = brain.company.value!.id;

    isLoading.value = true;
    try {
      final newEmployee = EmployeeModel(
        uid: '',
        companyId: companyId,
        name: name,
        email: email,
        tempPassword: null,
        hireDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        accountStatus: EmployeeAccountStatus.active,
        hourlyRate: rate,
        role: role.value,
        roleOther: role.value == EmployeeRole.otro ? roleOtherController.text.trim() : null,
        workdayType: workdayType.value,
        vacationDaysPer30: vac30,
        personalDaysPerYear: personal,
      );

      final result = await createEmployeeUseCase.call(newEmployee);
      if (!result.success || result.data == null) {
        final err = result.errorCode ?? 'No se pudo crear el empleado.';
        toastService.show(
          title: 'Error',
          description: err,
          type: ToastType.error
        );
        return;
      }

      toastService.show(
        title: 'Empleado creado',
        description: 'El empleado ha sido creado correctamente.',
        type: ToastType.success
      );

      Get.back();

      nameController.clear();
      emailController.clear();
      hourlyRateController.text = '0';
      vacationPer30Controller.text = '2.5';
      personalPerYearController.text = '0';
      role.value = EmployeeRole.tecnico;
      roleOtherController.clear();
      workdayType.value = null;
    } on Exception {
      toastService.show(
        title: 'Error',
        description: 'No se pudo crear el empleado.',
        type: ToastType.error
      );
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    emailController.dispose();
    hourlyRateController.dispose();
    vacationPer30Controller.dispose();
    personalPerYearController.dispose();
    roleOtherController.dispose();
    super.onClose();
  }
}