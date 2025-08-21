import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/company_model.dart';
import 'package:farmatime/domain/usecases/company/get_company_by_id_usecase.dart';
import 'package:farmatime/domain/usecases/firebase_auth/sign_in_with_email_usecase.dart';



class CompanyAuthSignInController extends GetxController {
  final SignInWithEmailUseCase signInWithEmailUseCase;
  final GetCompanyByIdUseCase getCompanyByIdUseCase;

  CompanyAuthSignInController({
    required this.signInWithEmailUseCase,
    required this.getCompanyByIdUseCase,
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

    print('SignIn Result: ${signInResult.success}, Data: ${signInResult.data}');

    if (!signInResult.success || signInResult.data == null) {
      Get.snackbar('Error', 'Credenciales incorrectas o cuenta inexistente');
      return;
    }

    final user = firebaseAuth.currentUser;
    if (user == null) {
      Get.snackbar('Error', 'No se pudo obtener el usuario actual');
      return;
    }

    final Result<CompanyModel?> companyResult =
        await getCompanyByIdUseCase.call(user.uid);

    if (!companyResult.success || companyResult.data == null) {
      Get.snackbar('Error', 'No se encontró una empresa asociada a esta cuenta');
      return;
    }
    print(1);

    brain.company.value = companyResult.data;
    await GetStorage().write('company', json.encode(companyResult.data!.toJson()));
    print(2);

    Get.offAllNamed(Routes.companyMain); // Ajusta la ruta según tu app
  }

  void recoverPassword() {
    // Puedes implementar este método más adelante
    print('Recuperar contraseña empresa');
  }

  void redirectToSignUp() {
    Get.toNamed(Routes.companyAuthSignUp);
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
