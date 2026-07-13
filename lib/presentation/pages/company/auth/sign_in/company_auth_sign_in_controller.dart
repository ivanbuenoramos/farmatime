import 'dart:async';
import 'dart:convert';
import 'package:farmatime/domain/repositories/chat_repository.dart';
import 'package:farmatime/presentation/pages/chat/chat/chat_binding.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/core/services/callable_http_client.dart';
import 'package:farmatime/core/services/toast_service.dart';
import 'package:farmatime/core/services/push_notification_service.dart';
import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/company_model.dart';
import 'package:farmatime/data/models/employee_model.dart';

// Usecases
import 'package:farmatime/domain/usecases/company/get_company_by_id_usecase.dart';
import 'package:farmatime/domain/usecases/firebase_auth/sign_in_with_email_usecase.dart';
import 'package:farmatime/domain/usecases/employee/get_employee_by_id_usecase.dart';
import 'package:farmatime/domain/usecases/employee/get_employees_by_company_id_usecase.dart';

// Chat

class CompanyAuthSignInController extends GetxController {
  final SignInWithEmailUseCase signInWithEmailUseCase;
  final GetCompanyByIdUseCase getCompanyByIdUseCase;
  final GetEmployeesByCompanyIdUseCase getEmployeesByCompanyIdUseCase;
  final GetEmployeeByIdUseCase getEmployeeByIdUseCase;

  CompanyAuthSignInController({
    required this.signInWithEmailUseCase,
    required this.getCompanyByIdUseCase,
    required this.getEmployeesByCompanyIdUseCase,
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
      ToastService().show(title: 'Error', message: 'Por favor, rellena todos los campos', type: ToastType.error);
      return;
    }

    final Result<UserCredential?> signInResult = await signInWithEmailUseCase.call(email, password);

    if (!signInResult.success || signInResult.data == null) {
      ToastService().show(title: 'Error', message: 'Credenciales incorrectas o cuenta inexistente', type: ToastType.error);
      return;
    }

    final user = firebaseAuth.currentUser;
    if (user == null) {
      ToastService().show(title: 'Error', message: 'No se pudo obtener el usuario actual', type: ToastType.error);
      return;
    }

    final Result<CompanyModel?> companyResult = await getCompanyByIdUseCase.call(user.uid);

    if (companyResult.success && companyResult.data != null) {
      final company = companyResult.data!;
      brain.company.value = company;
      await GetStorage().write('company', json.encode(company.toJson()));

      try {
        await _seedChatForExistingCompany(
          companyId: company.id,
          pharmacyUserId: user.uid,
          pharmacyDisplayName: company.legalName,
        );
      } catch (e, st) {
        debugPrint('Seed chat error: $e\n$st');
      }

      try {
        await _registerPushToken(company.id);
      } catch (e, st) {
        debugPrint('registerPushToken error (no-fatal): $e\n$st');
      }
      Get.offAllNamed(Routes.companyMain);
      unawaited(notifyLogin(company.email, company.legalName));
      return;
    }

    // Puede que sea un empleado que entró en el formulario de farmacia
    final Result<EmployeeModel?> employeeResult =
        await getEmployeeByIdUseCase.call(user.uid);

    if (employeeResult.success && employeeResult.data != null) {
      brain.employee.value = employeeResult.data;
      await GetStorage().write('employee', json.encode(employeeResult.data!.toJson()));
      try {
        await _registerPushToken(employeeResult.data!.uid);
      } catch (e, st) {
        debugPrint('registerPushToken error (no-fatal): $e\n$st');
      }
      Get.offAllNamed(Routes.employeeMain);
      return;
    }

    ToastService().show(title: 'Error', message: 'No se encontró ninguna cuenta asociada a este email', type: ToastType.error);
  }

  /// Registra el token FCM de este dispositivo para el usuario recién logueado.
  Future<void> _registerPushToken(String uid) async {
    if (!Get.isRegistered<PushNotificationService>()) return;
    await Get.find<PushNotificationService>().registerTokenForUser(uid);
  }

  void recoverPassword() => Get.toNamed(Routes.recoverPassword);

  void redirectToSignUp() => Get.toNamed(Routes.companyAuthSignUp);

  Future<void> notifyLogin(String email, String name) async {
    try {
      debugPrint('📩 Enviando notificación de inicio de sesión para $email / $name');
      // HTTP directo en lugar de httpsCallable: el SDK nativo de
      // FirebaseFunctions aborta la app en release (ver CallableHttpClient).
      await CallableHttpClient.call(
        'sendLoginNotification',
        {'email': email, 'name': name},
      );
    } catch (e, st) {
      debugPrint('notifyLogin error (no-fatal): $e\n$st');
    }
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  // ------------------------------------------------------------
  // CHAT SEEDING (usa el usecase de empleados)
  // ------------------------------------------------------------
  Future<void> _seedChatForExistingCompany({
    required String companyId,
    required String pharmacyUserId,
    required String pharmacyDisplayName,
  }) async {
    // Asegura el repo de chat
    if (!Get.isRegistered<ChatRepository>()) {
      ChatBinding().dependencies();
    }
    final repo = Get.find<ChatRepository>();

    // 1) Cargar empleados de la empresa vía usecase
    final employeesRes = await getEmployeesByCompanyIdUseCase.call(
      companyId: companyId,
      includeDeleted: false,
    );
    final List<EmployeeModel> employees =
        (employeesRes.success)
            ? employeesRes.data
            : const <EmployeeModel>[];

    final employeeIds = employees.map((e) => e.uid).toList();
    final employeeNamesById = {
      for (final e in employees) e.uid: (e.name)
    };

    // 2) Grupo "Todos"
    final allMemberIds = <String>{pharmacyUserId, ...employeeIds}.toList();
    await repo.ensureDefaultGroup(
      companyId: companyId,
      pharmacyUserId: pharmacyUserId,
      allMemberIds: allMemberIds,
    );

    // 3) 1:1 farmacia <-> empleado
    for (final empId in employeeIds) {
      final otherName = employeeNamesById[empId] ?? 'Empleado';
      await repo.ensureDirectConversation(
        companyId: companyId,
        userA: pharmacyUserId,
        userB: empId,
        titleOverride: otherName,
      );
    }
  }
}