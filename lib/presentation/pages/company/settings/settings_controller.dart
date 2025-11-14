import 'dart:io';
import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/domain/usecases/firebase_auth/log_out_usecase.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:farmatime/core/routes/routes.dart';

class SettingsController extends GetxController {

  final LogOutUseCase logOutUseCase;

  SettingsController({
    required this.logOutUseCase,
  });

  final Brain brain = Get.find<Brain>();

  final List<Locale> supportedLocales = const [
    Locale('es', 'ES'),
    Locale('en', 'US'),
  ];

  final Rx<Locale> currentLocale = const Locale('es', 'ES').obs;

  /// Versión de la app
  final RxString appVersion = '—'.obs;

  /// Loading para acciones críticas (eliminar, cerrar sesión)
  final RxBool isBusy = false.obs;

  @override
  void onInit() {
    super.onInit();
    _initLocale();
    _loadAppVersion();
  }

  void _initLocale() {
    final loc = Get.locale ?? Get.deviceLocale ?? const Locale('es', 'ES');
    // Asegurar que sea uno de los soportados
    currentLocale.value =
        supportedLocales.firstWhere((l) => l.languageCode == loc.languageCode,
            orElse: () => const Locale('es', 'ES'));
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion.value = '${info.buildSignature.isEmpty ? '' : ''}'
          '${info.appName} '
          'v${info.version} (${info.buildNumber})';
    } catch (_) {
      // fallback corto si no hay permisos o falla el plugin
      appVersion.value = 'v1.0.0';
    }
  }

  /// Abrir ajustes del sistema (permisos)
  Future<void> openSystemSettings() async {
    await openAppSettings();
  }

  /// Cambiar idioma
  void changeLanguage(Locale locale) {
    currentLocale.value = locale;
    Get.updateLocale(locale);
  }

  /// Cerrar sesión
  void logOut() async {
    Get.offNamed(Routes.index);
    await logOutUseCase.call();
    brain.clearSession();
  }

  /// Eliminar cuenta
  Future<void> deleteAccount() async {
    final confirm = await _confirm(
      title: 'Eliminar cuenta',
      message: 'Esta acción es permanente y borrará tus datos. ¿Deseas continuar?',
      confirmText: 'Eliminar',
      destructive: true,
    );
    if (confirm != true) return;

    try {
      isBusy.value = true;
      // TODO: Llama a tu endpoint/servicio para eliminar la cuenta
      // await Get.find<AuthService>().deleteAccount();
      await Future.delayed(const Duration(milliseconds: 800));
      Get.offAllNamed('/auth');
      Get.snackbar('Cuenta eliminada', 'Tu cuenta ha sido eliminada correctamente.',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isBusy.value = false;
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    String confirmText = 'Aceptar',
    String cancelText = 'Cancelar',
    bool destructive = false,
  }) async {
    return Get.dialog<bool>(
      AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: Text(cancelText)),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  )
                : null,
            onPressed: () => Get.back(result: true),
            child: Text(confirmText),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  String languageName(Locale l) {
    switch ('${l.languageCode}_${l.countryCode ?? ''}') {
      case 'es_ES':
        return 'Español';
      case 'en_US':
        return 'English';
      default:
        return l.toLanguageTag();
    }
  }

  String get platformSettingsHint =>
      Platform.isIOS ? 'Abrir ajustes del sistema' : 'Abrir ajustes del dispositivo';
}