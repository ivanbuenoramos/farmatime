import 'dart:math';

import 'package:farmatime/domain/usecases/firebase_auth/sign_up_with_email_usecase.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/domain/usecases/employee/create_employee_usecase.dart';



class CreateEmployeeController extends GetxController {
  
  final CreateEmployeeUseCase createEmployeeUseCase;
  final SignUpWithEmailUseCase signUpWithEmailUseCase;

  CreateEmployeeController({
    required this.createEmployeeUseCase,
    required this.signUpWithEmailUseCase,
  });

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final isLoading = false.obs;

  final Brain brain = Get.find<Brain>();

  String _generateTemporaryPassword() {
    const chars = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ123456789@#\$%!&';
    final rand = Random();
    return List.generate(10, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<void> createEmployee() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();

    if (name.isEmpty || email.isEmpty || !GetUtils.isEmail(email)) {
      Get.snackbar('Error', 'Por favor, introduce un nombre y correo válidos.');
      return;
    }

    isLoading.value = true;

    try {
      final password = _generateTemporaryPassword();

      // 1. Crear usuario en Firebase Auth
      final authResult = await signUpWithEmailUseCase.call(
        email,
        password,
      );

      if (!authResult.success) {
        Get.snackbar('Error', 'No se pudo crear el usuario: ${authResult.errorCode}');
        return;
      }

      final uid = (authResult.data as UserCredential).user?.uid;
      if (uid == null) throw Exception('No se pudo obtener UID');

      // 2. Crear modelo de empleado
      final newEmployee = EmployeeModel(
        uid: uid,
        companyId: brain.company.value!.id,
        name: name,
        email: email,
        tempPassword: password,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(), 
        isActive: true,
      );

      // 3. Guardar en Firestore
      final result = await createEmployeeUseCase.call(newEmployee);

      if (!result.success) {
        Get.snackbar('Error', 'No se pudo guardar el empleado en la base de datos');
        return;
      }

      // 4. Mostrar la contraseña temporal
      Get.snackbar(
        'Empleado creado',
        'Se ha enviado la contraseña temporal a $email:\n$password',
        duration: const Duration(seconds: 6),
      );

      nameController.clear();
      emailController.clear();
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
    super.onClose();
  }
}
