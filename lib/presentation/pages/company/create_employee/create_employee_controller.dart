import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/domain/usecases/employee/create_employee_usecase.dart';



class CreateEmployeeController extends GetxController {
  final CreateEmployeeUseCase createEmployeeUseCase;

  CreateEmployeeController({required this.createEmployeeUseCase});

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final hourlyRateController = TextEditingController(text: '0');
  final vacationPer30Controller = TextEditingController(text: '2.5');
  final personalPerYearController = TextEditingController(text: '0');
  final roleOtherController = TextEditingController();

  final role = EmployeeRole.tecnico.obs;
  final workdayType = Rx<WorkdayType?>(null);

  final isLoading = false.obs;
  final Brain brain = Get.find<Brain>();

  double _parseDouble(TextEditingController c, {double def = 0}) {
    final s = c.text.trim().replaceAll(',', '.');
    return double.tryParse(s) ?? def;
  }

  Future<void> createEmployee() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();

    if (name.isEmpty || email.isEmpty || !GetUtils.isEmail(email)) {
      Get.snackbar('Error', 'Por favor, introduce un nombre y correo válidos.');
      return;
    }

    // Validaciones campos nuevos (cliente)
    final rate = _parseDouble(hourlyRateController);
    final vac30 = _parseDouble(vacationPer30Controller, def: 2.5);
    final personal = _parseDouble(personalPerYearController);

    if (rate < 0) {
      Get.snackbar('Error', 'El precio por hora no puede ser negativo.');
      return;
    }
    if (vac30 < 0) {
      Get.snackbar('Error', 'Los días de vacaciones/30 días no pueden ser negativos.');
      return;
    }
    if (personal < 0) {
      Get.snackbar('Error', 'Los días de asuntos propios/año no pueden ser negativos.');
      return;
    }
    if (role.value == EmployeeRole.otro && roleOtherController.text.trim().isEmpty) {
      Get.snackbar('Error', 'Indica el cargo en "Otro (especificar)".');
      return;
    }

    final companyId = brain.company.value!.id;

    isLoading.value = true;
    try {
      // Creamos un modelo "parcial": el uid lo asignará el servidor.
      final newEmployee = EmployeeModel(
        uid: '', // ignorado por el repo; el servidor generará uno
        companyId: companyId,
        name: name,
        email: email,
        tempPassword: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
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
        Get.snackbar('Error', err);
        return;
      }

      // UX final
      Get.snackbar(
        'Empleado creado',
        'Se ha creado la cuenta para $email. Recibirá un email para establecer su contraseña.',
        duration: const Duration(seconds: 6),
      );

      // Limpiar formularios
      nameController.clear();
      emailController.clear();
      hourlyRateController.text = '0';
      vacationPer30Controller.text = '2.5';
      personalPerYearController.text = '0';
      role.value = EmployeeRole.tecnico;
      roleOtherController.clear();
      workdayType.value = null;
    } on Exception catch (e) {
      Get.snackbar('Error', e.toString());
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