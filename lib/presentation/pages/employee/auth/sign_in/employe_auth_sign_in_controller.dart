import 'dart:convert';

import 'package:farmatime/core/routes/routes.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/domain/usecases/employee/get_employee_by_id_usecase.dart';
import 'package:farmatime/domain/usecases/firebase_auth/sign_in_with_email_usecase.dart';



class EmployeeAuthSignInController extends GetxController {
  final SignInWithEmailUseCase signInWithEmailUseCase;
  final GetEmployeeByIdUseCase getEmployeeByIdUseCase;

  EmployeeAuthSignInController({
    required this.signInWithEmailUseCase,
    required this.getEmployeeByIdUseCase,
  });

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final rememberMe = false.obs;

  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  final Brain brain = Get.find<Brain>();

  void setRememberMe(bool? value) {
    if (value != null) rememberMe.value = value;
  }

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      Get.snackbar('Error', 'Por favor, rellena todos los campos');
      return;
    }

    final Result<UserCredential?> signInResult =
        await signInWithEmailUseCase.call(email, password);

    if (!signInResult.success || signInResult.data == null) {
      Get.snackbar('Error', 'Credenciales incorrectas o cuenta inexistente');
      return;
    }

    final user = firebaseAuth.currentUser;
    if (user == null) {
      Get.snackbar('Error', 'No se pudo obtener el usuario actual');
      return;
    }

    final Result<EmployeeModel?> employeeResult =
        await getEmployeeByIdUseCase.call(user.uid);

    print(employeeResult.toJson());

    if (!employeeResult.success || employeeResult.data == null) {
      Get.snackbar('Error', 'No se encontró un empleado con esta cuenta');
      return;
    }

    brain.employee.value = employeeResult.data;
    await GetStorage().write('employee', json.encode(employeeResult.data!.toJson()));

    Get.offAllNamed(Routes.employeeMain);
  }

  void recoverPassword() => Get.toNamed(Routes.recoverPassword);

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}

