import 'dart:convert';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/domain/usecases/firebase_auth/sign_up_with_email_usecase.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/company_model.dart';
import 'package:farmatime/domain/usecases/company/create_company_usecase.dart';

class CompanyAuthSignUpController extends GetxController {
  final SignUpWithEmailUseCase signUpWithEmailUseCase;
  final CreateCompanyUseCase createCompanyUseCase;

  CompanyAuthSignUpController({
    required this.signUpWithEmailUseCase,
    required this.createCompanyUseCase,
  });

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final Rx<String?> nameError = Rx<String?>(null);
  final Rx<String?> emailError = Rx<String?>(null);
  final Rx<String?> passwordError = Rx<String?>(null);

  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  final Brain brain = Get.find<Brain>();

  bool validateForm() {
    bool isValid = true;

    if (nameController.text.isEmpty) {
      nameError.value = 'Campo requerido';
      isValid = false;
    } else if (!GetUtils.isLengthBetween(nameController.text, 2, 50)) {
      nameError.value = 'Debe tener entre 2 y 50 caracteres';
      isValid = false;
    } else {
      nameError.value = null;
    }

    if (emailController.text.isEmpty) {
      emailError.value = 'Campo requerido';
      isValid = false;
    } else if (!GetUtils.isEmail(emailController.text.trim())) {
      emailError.value = 'Email inválido';
      isValid = false;
    } else {
      emailError.value = null;
    }

    if (passwordController.text.isEmpty) {
      passwordError.value = 'Campo requerido';
      isValid = false;
    } else if (!GetUtils.isLengthBetween(passwordController.text, 6, 20)) {
      passwordError.value = 'Debe tener entre 6 y 20 caracteres';
      isValid = false;
    } else {
      passwordError.value = null;
    }

    return isValid;
  }

  Future<void> register() async {
    if (!validateForm()) return;

    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final name = nameController.text.trim();

    final Result<UserCredential?> signUpResult =
        await signUpWithEmailUseCase.call(email, password);

    if (!signUpResult.success || signUpResult.data == null) {
      Get.snackbar('Error', 'No se pudo crear la cuenta');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final company = CompanyModel(
      id: user.uid,
      email: email,
      purchasedEmployeeSlots: 0,
      legalName: name,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(), 
    );

    final Result<CompanyModel?> createResult =
        await createCompanyUseCase.call(company);

    if (!createResult.success || createResult.data == null) {
      Get.snackbar('Error', 'No se pudo crear la empresa');
      return;
    }

    brain.company.value = createResult.data;
    await GetStorage().write('company', json.encode(company.toJson()));

    await user.updateDisplayName(name);
    await user.reload();

    Get.offAllNamed(Routes.companyMain);
  }

  @override
  void onClose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
