import 'dart:async';
import 'dart:convert';

import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/core/services/callable_http_client.dart';
import 'package:farmatime/core/services/push_notification_service.dart';
import 'package:farmatime/core/services/toast_service.dart';
import 'package:farmatime/domain/repositories/chat_repository.dart';
import 'package:farmatime/presentation/pages/chat/chat/chat_binding.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/company_model.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/domain/usecases/company/get_company_by_id_usecase.dart';
import 'package:farmatime/domain/usecases/employee/get_employee_by_id_usecase.dart';
import 'package:farmatime/domain/usecases/employee/get_employees_by_company_id_usecase.dart';
import 'package:farmatime/domain/usecases/firebase_auth/sign_in_with_email_usecase.dart';



class EmployeeAuthSignInController extends GetxController {
  final SignInWithEmailUseCase signInWithEmailUseCase;
  final GetEmployeeByIdUseCase getEmployeeByIdUseCase;
  final GetCompanyByIdUseCase getCompanyByIdUseCase;
  final GetEmployeesByCompanyIdUseCase getEmployeesByCompanyIdUseCase;

  EmployeeAuthSignInController({
    required this.signInWithEmailUseCase,
    required this.getEmployeeByIdUseCase,
    required this.getCompanyByIdUseCase,
    required this.getEmployeesByCompanyIdUseCase,
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

    final Result<UserCredential?> signInResult =
        await signInWithEmailUseCase.call(email, password);

    if (!signInResult.success || signInResult.data == null) {
      ToastService().show(title: 'Error', message: 'Credenciales incorrectas o cuenta inexistente', type: ToastType.error);
      return;
    }

    final user = firebaseAuth.currentUser;
    if (user == null) {
      ToastService().show(title: 'Error', message: 'No se pudo obtener el usuario actual', type: ToastType.error);
      return;
    }

    final Result<EmployeeModel?> employeeResult =
        await getEmployeeByIdUseCase.call(user.uid);

    if (employeeResult.success && employeeResult.data != null) {
      brain.employee.value = employeeResult.data;
      await GetStorage().write('employee', json.encode(employeeResult.data!.toJson()));
      await _registerPushToken(employeeResult.data!.uid);
      Get.offAllNamed(Routes.employeeMain);
      return;
    }

    // Puede que sea una farmacia que entró en el formulario de empleado
    final Result<CompanyModel?> companyResult =
        await getCompanyByIdUseCase.call(user.uid);

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

      await _registerPushToken(company.id);
      Get.offAllNamed(Routes.companyMain);
      unawaited(_notifyLogin(company.email, company.legalName));
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

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  Future<void> _notifyLogin(String email, String name) async {
    try {
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

  Future<void> _seedChatForExistingCompany({
    required String companyId,
    required String pharmacyUserId,
    required String pharmacyDisplayName,
  }) async {
    if (!Get.isRegistered<ChatRepository>()) {
      ChatBinding().dependencies();
    }
    final repo = Get.find<ChatRepository>();

    final employeesRes = await getEmployeesByCompanyIdUseCase.call(
      companyId: companyId,
      includeDeleted: false,
    );
    final List<EmployeeModel> employees =
        employeesRes.success ? employeesRes.data : const <EmployeeModel>[];

    final employeeIds = employees.map((e) => e.uid).toList();
    final employeeNamesById = {for (final e in employees) e.uid: e.name};

    final allMemberIds = <String>{pharmacyUserId, ...employeeIds}.toList();
    await repo.ensureDefaultGroup(
      companyId: companyId,
      pharmacyUserId: pharmacyUserId,
      allMemberIds: allMemberIds,
    );

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

