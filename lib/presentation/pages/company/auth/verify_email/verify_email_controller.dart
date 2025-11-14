import 'dart:async';

import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/domain/usecases/firebase_auth/log_out_usecase.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:farmatime/core/app/brain.dart';

import 'package:farmatime/data/models/company_model.dart';
import 'package:farmatime/domain/usecases/company/update_company_usecase.dart';



class VerifyEmailController extends GetxController {
  
  final UpdateCompanyUsecase updateCompanyUseCase;
  final LogOutUseCase logoutUseCase;

  VerifyEmailController({
    required this.updateCompanyUseCase,
    required this.logoutUseCase,
  });


  final _auth = FirebaseAuth.instance;
  final Brain brain = Get.find<Brain>();

  final isSending = false.obs;
  final isChecking = false.obs;
  final emailSent = false.obs;
  final canResend = true.obs;
  final secondsToResend = 0.obs;
  final verified = false.obs;

  Timer? _pollTimer;
  Timer? _cooldownTimer;

  String? companyId;
  CompanyModel? company;

  String? get email => _auth.currentUser?.email;
  bool get isEmailVerifiedFlag => _auth.currentUser?.emailVerified == true;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map?;
    companyId = args?['companyId'];
    company = args?['company']; // se pasa el modelo completo

    if (isEmailVerifiedFlag) _onVerified();
  }

  @override
  void onClose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    super.onClose();
  }

  Future<void> sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) return;

    isSending.value = true;
    try {
      await user.sendEmailVerification();
      emailSent.value = true;
      _startPolling();
      _startCooldown(seconds: 60);
    } catch (e) {
      Get.snackbar('Error', 'No se pudo enviar el email: $e');
    } finally {
      isSending.value = false;
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => checkNow());
  }

  void logOut() async {
    await logoutUseCase();
    Get.offAllNamed(Routes.index);
  }

  void _startCooldown({required int seconds}) {
    canResend.value = false;
    secondsToResend.value = seconds;

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = secondsToResend.value - 1;
      secondsToResend.value = left;
      if (left <= 0) {
        canResend.value = true;
        t.cancel();
      }
    });
  }

  Future<void> checkNow() async {
    isChecking.value = true;
    try {
      await _auth.currentUser?.reload();
      if (isEmailVerifiedFlag) {
        _pollTimer?.cancel();
        _onVerified();
      }
    } finally {
      isChecking.value = false;
    }
  }

  Future<void> _ensureCompanyLoaded() async {
    if (company != null) return;

    company ??= brain.company.value;
    companyId ??= company?.id;
    if (company != null) return;

    await brain.loadSession();
    company ??= brain.company.value;
    companyId ??= company?.id;
  }

  Future<void> _onVerified() async {
    verified.value = true;

    await _ensureCompanyLoaded();
    if (company == null) {
      Get.snackbar('Error', 'No se encontró la compañía.');
      return;
    }

    try {
      final updatedCompany = company!.copyWith(verifiedEmail: true);
      await updateCompanyUseCase(updatedCompany);
      company = updatedCompany;
      brain.company.value = updatedCompany;

      Get.snackbar('¡Listo!', 'Email verificado correctamente.');
      Get.back();
    } catch (e) {
      Get.snackbar('Error', 'No se pudo actualizar la compañía: $e');
    }
  }
}
