import 'dart:convert';

import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/domain/repositories/chat_repository.dart';
import 'package:farmatime/presentation/pages/chat/chat/chat_binding.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;

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

  final FirebaseFunctions functions = FirebaseFunctions.instanceFor(
    app: Firebase.app(),
    region: 'europe-west1',
  );

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

    if (employeeResult.success && employeeResult.data != null) {
      brain.employee.value = employeeResult.data;
      await GetStorage().write('employee', json.encode(employeeResult.data!.toJson()));
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

      Get.offAllNamed(Routes.companyMain);
      _notifyLogin(company.email, company.legalName);
      return;
    }

    Get.snackbar('Error', 'No se encontró ninguna cuenta asociada a este email');
  }

  void recoverPassword() => Get.toNamed(Routes.recoverPassword);

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  Future<void> _notifyLogin(String email, String name) async {
    final callable = functions.httpsCallable('sendLoginNotification');
    await callable.call({'email': email, 'name': name});
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

