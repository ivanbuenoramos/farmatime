import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart'; // 👈
import 'package:farmatime/domain/usecases/firebase_auth/sign_up_with_email_usecase.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/domain/usecases/employee/create_employee_usecase.dart';
// (opcional) para navegar a suscripción
import 'package:farmatime/core/routes/routes.dart';

class CreateEmployeeController extends GetxController {
  final CreateEmployeeUseCase createEmployeeUseCase;
  final SignUpWithEmailUseCase signUpWithEmailUseCase;

  CreateEmployeeController({
    required this.createEmployeeUseCase,
    required this.signUpWithEmailUseCase,
  });

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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // 👈

  String _generateTemporaryPassword() {
    const chars = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ123456789@#\$%!&';
    final rand = Random();
    return List.generate(10, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  double _parseDouble(TextEditingController c, {double def = 0}) {
    final s = c.text.trim().replaceAll(',', '.');
    return double.tryParse(s) ?? def;
  }

  Future<int> _activeEmployeesCount(String companyId) async {
    final q = await _firestore
        .collection('employees')
        .where('companyId', isEqualTo: companyId)
        .where('isActive', isEqualTo: true)
        .get();
    return q.size;
  }

  int _contractedSeats() {
    final c = brain.company.value;
    // Fuente de verdad: contractedSeats (Stripe). Fallback al legacy purchasedEmployeeSlots.
    return (c?.contractedSeats ?? c?.purchasedEmployeeSlots ?? 0);
  }

  Future<void> _showNoSeatsDialog() async {
    await Get.dialog(
      AlertDialog(
        title: const Text('Sin plazas disponibles'),
        content: const Text(
            'Para crear un nuevo empleado necesitas contratar una plaza adicional. ¿Quieres ir a Suscripción ahora?'),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Get.back();
              // Get.toNamed(Routes.subscription); // ajusta tu ruta
            },
            child: const Text('Ir a Suscripción'),
          ),
        ],
      ),
      barrierDismissible: true,
    );
  }

  Future<void> createEmployee() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();

    if (name.isEmpty || email.isEmpty || !GetUtils.isEmail(email)) {
      Get.snackbar('Error', 'Por favor, introduce un nombre y correo válidos.');
      return;
    }

    // 🔒 COMPROBACIÓN DE CUPOS
    final companyId = brain.company.value!.id;
    final maxSeats = _contractedSeats();
    final current = await _activeEmployeesCount(companyId);
    if (current >= maxSeats) {
      await _showNoSeatsDialog();
      return;
    }

    // Validaciones nuevos campos
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

    isLoading.value = true;

    try {
      final password = _generateTemporaryPassword();

      // 1) Firebase Auth
      final authResult = await signUpWithEmailUseCase.call(email, password);
      if (!authResult.success) {
        Get.snackbar('Error', 'No se pudo crear el usuario: ${authResult.errorCode}');
        return;
      }
      final uid = (authResult.data as UserCredential).user?.uid;
      if (uid == null) throw Exception('No se pudo obtener UID');

      // 2) Modelo
      final newEmployee = EmployeeModel(
        uid: uid,
        companyId: companyId,
        name: name,
        email: email,
        tempPassword: password,
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

      // 3) Persistir
      final result = await createEmployeeUseCase.call(newEmployee);
      if (!result.success) {
        Get.snackbar('Error', 'No se pudo guardar el empleado en la base de datos');
        return;
      }

      Get.snackbar(
        'Empleado creado',
        'Se ha enviado la contraseña temporal a $email:\n$password',
        duration: const Duration(seconds: 6),
      );

      // Limpiar
      nameController.clear();
      emailController.clear();
      hourlyRateController.text = '0';
      vacationPer30Controller.text = '2.5';
      personalPerYearController.text = '0';
      role.value = EmployeeRole.tecnico;
      roleOtherController.clear();
      workdayType.value = null;
    } on FirebaseAuthException catch (e) {
      Get.snackbar('Error Firebase', e.message ?? 'Error desconocido');
    } catch (e) {
      Get.snackbar('Error', 'No se pudo crear el empleado: ${e.toString()}');
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