import 'dart:convert';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/domain/usecases/firebase_auth/sign_up_with_email_usecase.dart';
import 'package:farmatime/domain/usecases/stripe/create_stripe_customer_usecase.dart';
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

  // ⬇️ NUEVO: inyecta este usecase
  final CreateStripeCustomerUseCase createStripeCustomerUseCase;

  CompanyAuthSignUpController({
    required this.signUpWithEmailUseCase,
    required this.createCompanyUseCase,
    required this.createStripeCustomerUseCase, // ⬅️ nuevo
  });

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final Rx<String?> nameError = Rx<String?>(null);
  final Rx<String?> emailError = Rx<String?>(null);
  final Rx<String?> passwordError = Rx<String?>(null);

  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  final Brain brain = Get.find<Brain>();

  final isLoading = false.obs; // ⬅️ opcional para deshabilitar el botón

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

    isLoading.value = true;

    try {
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
      if (user == null) {
        Get.snackbar('Error', 'Sesión no encontrada tras el registro');
        return;
      }

      // 1) Crear documento de empresa en Firestore
      final company = CompanyModel(
        id: user.uid,
        email: email,
        purchasedEmployeeSlots: 0,
        legalName: name,
        verifiedEmail: false,
        verifiedPhone: false,
        billingStatus: 'none',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final Result<CompanyModel?> createResult =
          await createCompanyUseCase.call(company);

      if (!createResult.success || createResult.data == null) {
        Get.snackbar('Error', 'No se pudo crear la empresa');
        return;
      }

      // Guarda en memoria local
      brain.company.value = createResult.data;
      await GetStorage().write('company', json.encode(createResult.data!.toJson()));

      // 2) NUEVO: Crear en Stripe (Customer + Subscription) vía Cloud Function

      await FirebaseAuth.instance.currentUser?.reload();
      await FirebaseAuth.instance.currentUser?.getIdToken(true);

      //    initialQuantity: 1 para que encaje con tu precio por niveles (1º gratis).
      final stripeRes = await createStripeCustomerUseCase.call(companyId: company.id);

      print(stripeRes.toJson());

      if (!stripeRes.success) {
        // No bloqueamos el flujo de onboarding, pero informamos.
        // El webhook o un botón de "Reintentar" en la pantalla de suscripción podría solventarlo.
        Get.snackbar(
          'Atención',
          'La configuración de facturación no se completó. Puedes reintentarlo desde Suscripción.',
        );
      }

      // 3) Actualizar perfil del usuario de Firebase (cosmético)
      await user.updateDisplayName(name);
      await user.reload();

      // 4) Navegar a la app de empresa
      Get.offAllNamed(Routes.companyMain);
    } catch (e) {
      print(e);
      Get.snackbar('Error', 'Ocurrió un problema durante el registro');
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}