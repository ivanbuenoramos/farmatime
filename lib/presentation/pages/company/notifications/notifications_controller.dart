import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/services/toast_service.dart';
import 'package:farmatime/data/repositories/fcm_token_repository_impl.dart';
import 'package:farmatime/domain/repositories/fcm_token_repository.dart';

class NotificationsController extends GetxController {
  NotificationsController({FcmTokenRepository? prefsRepository})
      : _prefsRepository = prefsRepository ?? FcmTokenRepositoryImpl();

  static const String _storageKey = 'notification_prefs';

  /// Las preferencias se guardan en Firestore (user_fcm_tokens/{uid}.prefs)
  /// para que el backend (sendPush.js) las respete al enviar. GetStorage actúa
  /// solo como caché local mientras llega la copia remota.
  final FcmTokenRepository _prefsRepository;

  final GetStorage _storage = GetStorage();

  final RxBool pushEnabled = true.obs;

  final RxBool leaveRequests = true.obs;
  final RxBool leaveStatusUpdates = true.obs;

  final RxBool scheduleChanges = true.obs;

  final RxBool chatMessages = true.obs;

  final RxBool systemPermissionGranted = true.obs;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// La pantalla es compartida (Ajustes es común a ambos roles): cada rol ve
  /// solo los toggles de los tipos de push que realmente recibe. Mismo
  /// criterio de rol que PushNotificationService._routeFromData.
  bool get isCompany => Get.find<Brain>().company.value != null;

  @override
  void onInit() {
    super.onInit();
    _loadLocalPrefs();
    _loadRemotePrefs();
    _refreshSystemPermission();
  }

  @override
  void onReady() {
    super.onReady();
    _refreshSystemPermission();
  }

  Map<String, bool> get _currentPrefs => {
        'pushEnabled': pushEnabled.value,
        'leaveRequests': leaveRequests.value,
        'leaveStatusUpdates': leaveStatusUpdates.value,
        'scheduleChanges': scheduleChanges.value,
        'chatMessages': chatMessages.value,
      };

  void _applyPrefs(Map<dynamic, dynamic> data) {
    pushEnabled.value = data['pushEnabled'] ?? true;
    leaveRequests.value = data['leaveRequests'] ?? true;
    leaveStatusUpdates.value = data['leaveStatusUpdates'] ?? true;
    scheduleChanges.value = data['scheduleChanges'] ?? true;
    chatMessages.value = data['chatMessages'] ?? true;
  }

  void _loadLocalPrefs() {
    final raw = _storage.read(_storageKey);
    if (raw is! Map) return;
    _applyPrefs(raw);
  }

  Future<void> _loadRemotePrefs() async {
    final uid = _uid;
    if (uid == null) return;
    final res = await _prefsRepository.loadPushPrefs(uid: uid);
    // null = nunca guardadas en Firestore: se mantiene lo local/por defecto.
    if (!res.success || res.data == null) return;
    _applyPrefs(res.data!);
    await _storage.write(_storageKey, _currentPrefs);
  }

  Future<void> _persist() async {
    await _storage.write(_storageKey, _currentPrefs);

    final uid = _uid;
    if (uid == null) return;
    final res = await _prefsRepository.savePushPrefs(
      uid: uid,
      prefs: _currentPrefs,
    );
    if (!res.success) {
      ToastService().show(
        title: 'Error',
        message:
            'No se pudieron sincronizar las preferencias. Inténtalo de nuevo.',
        type: ToastType.error,
      );
    }
  }

  Future<void> _refreshSystemPermission() async {
    final status = await Permission.notification.status;
    systemPermissionGranted.value = status.isGranted || status.isLimited;
  }

  Future<void> requestSystemPermission() async {
    final status = await Permission.notification.request();
    systemPermissionGranted.value = status.isGranted || status.isLimited;
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
  }

  Future<void> openSystemSettings() async {
    await openAppSettings();
    await _refreshSystemPermission();
  }

  Future<void> togglePush(bool value) async {
    pushEnabled.value = value;
    await _persist();
  }

  Future<void> toggle(RxBool flag, bool value) async {
    flag.value = value;
    await _persist();
  }

  String get systemPermissionHint {
    if (systemPermissionGranted.value) {
      return Platform.isIOS
          ? 'Permitidas en ajustes del sistema'
          : 'Permitidas en ajustes del dispositivo';
    }
    return 'Permiso desactivado. Toca para activarlo.';
  }
}
