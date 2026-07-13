import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/data/repositories/fcm_token_repository_impl.dart';
import 'package:farmatime/domain/repositories/fcm_token_repository.dart';
import 'package:farmatime/presentation/pages/company/main/company_main_controller.dart';
import 'package:farmatime/presentation/pages/employee/main/employee_main_controller.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

/// Handler de mensajes recibidos cuando la app está en segundo plano o cerrada.
///
/// Debe ser una función top-level (o estática) anotada con `@pragma` para que
/// sobreviva al tree-shaking y pueda ejecutarse en un isolate aparte.
/// No tocamos UI ni estado de GetX aquí: el sistema operativo ya muestra la
/// notificación; este handler solo existe para poder hacer trabajo en bg si
/// hiciera falta en el futuro.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No es necesario Firebase.initializeApp aquí salvo que se acceda a otros
  // servicios de Firebase desde el isolate de background. Lo dejamos vacío.
}

/// Servicio central de notificaciones push (FCM) + notificaciones locales.
///
/// Responsabilidades:
///  - Inicializar FCM y el plugin de notificaciones locales (canal Android).
///  - Pedir permiso de notificaciones al usuario.
///  - Registrar / refrescar / borrar el token del usuario en Firestore.
///  - Mostrar la notificación cuando llega en primer plano (FCM no la pinta).
///  - Enrutar a la pantalla correcta cuando el usuario toca la notificación.
class PushNotificationService extends GetxService {
  PushNotificationService({FcmTokenRepository? tokenRepository})
      : _tokenRepository = tokenRepository ?? FcmTokenRepositoryImpl();

  final FcmTokenRepository _tokenRepository;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSub;

  /// uid del usuario para el que se registró el último token. Se guarda para
  /// poder borrar el token correcto al cerrar sesión.
  String? _registeredUid;
  String? _currentToken;

  bool _initialized = false;

  /// Canal Android para notificaciones de alta prioridad (heads-up).
  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    'farmatime_default',
    'Notificaciones de Farmatime',
    description: 'Avisos de turnos, ausencias, fichajes, chat y suscripción.',
    importance: Importance.high,
  );

  /// Inicializa el plugin local, los handlers de FCM y registra el background
  /// handler. Idempotente. Se llama una vez al arrancar la app.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _initLocalNotifications();
    await _requestPermission();

    // iOS: mostrar la notificación también en primer plano (banner + sonido).
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Mensaje recibido con la app en primer plano → lo pintamos nosotros.
    _onMessageSub = FirebaseMessaging.onMessage.listen(_showLocalFromRemote);

    // Mensaje tocado con la app en background (no terminada).
    _onMessageOpenedSub =
        FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);

    // Mensaje que abrió la app desde estado terminado.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      // Pequeño delay para asegurar que GetX y las rutas están listas.
      Future.delayed(const Duration(milliseconds: 800), () {
        _handleOpenedMessage(initialMessage);
      });
    }

    // Si el token cambia (rotación de FCM), lo re-guardamos para el usuario.
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) {
      _currentToken = token;
      if (_registeredUid != null) {
        _tokenRepository.saveToken(
          uid: _registeredUid!,
          token: token,
          platform: _platform,
        );
      }
    });
  }

  Future<void> _initLocalNotifications() async {
    const androidInit =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = Map<String, dynamic>.from(json.decode(payload));
          _routeFromData(data);
        } catch (_) {}
      },
    );

    // Crea el canal en Android (no-op en iOS).
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
  }

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Registra el token del usuario [uid] en Firestore. Llamar tras login.
  Future<void> registerTokenForUser(String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      _currentToken = token;
      _registeredUid = uid;
      await _tokenRepository.saveToken(
        uid: uid,
        token: token,
        platform: _platform,
      );
    } catch (e) {
      print('PushNotificationService.registerTokenForUser error: $e');
    }
  }

  /// Borra el token de este dispositivo para el usuario actual. Llamar al
  /// cerrar sesión, antes de limpiar el estado, para no seguir recibiendo
  /// notificaciones de una cuenta de la que se ha salido.
  Future<void> unregisterTokenForCurrentUser() async {
    try {
      final uid = _registeredUid;
      final token = _currentToken ?? await _messaging.getToken();
      if (uid != null && token != null) {
        await _tokenRepository.deleteToken(uid: uid, token: token);
      }
      // Invalida el token local para que el próximo login obtenga uno nuevo.
      await _messaging.deleteToken();
    } catch (e) {
      print('PushNotificationService.unregisterTokenForCurrentUser error: $e');
    } finally {
      _registeredUid = null;
      _currentToken = null;
    }
  }

  /// Pinta una notificación local a partir de un [RemoteMessage] recibido en
  /// primer plano (en ese estado FCM no muestra nada por sí mismo en Android).
  Future<void> _showLocalFromRemote(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'];
    final body = notification?.body ?? message.data['body'];
    if (title == null && body == null) return;

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/launcher_icon',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: json.encode(message.data),
    );
  }

  void _handleOpenedMessage(RemoteMessage message) {
    _routeFromData(message.data);
  }

  /// Enruta a la pantalla correspondiente según el campo `type` del payload.
  /// El backend debe incluir en `data` al menos `type`, y los ids necesarios
  /// (p.ej. `conversationId`). Mantener este contrato sincronizado con el
  /// helper de envío de Cloud Functions.
  void _routeFromData(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    if (type == null) return;

    final brain = Get.isRegistered<Brain>() ? Get.find<Brain>() : null;
    final isCompany = brain?.company.value != null;

    switch (type) {
      case 'chat_message':
        // Lleva a la pestaña de Chat del main (índice 2 en ambos roles).
        // No abrimos la conversación concreta porque la pantalla de chat
        // requiere el objeto Conversation completo; el inbox la muestra arriba
        // con su badge de no leídos.
        _goToTab(isCompany, 2);
        break;
      case 'leave_request': // empresa: solicitud nueva / cancelada / respondida
        Get.toNamed(Routes.companyTimeOff);
        break;
      case 'leave_status': // empleado: aprobada / rechazada / propuesta
        Get.toNamed(Routes.employeeRequestLeave);
        break;
      case 'schedule_change': // empleado: cambio de turno / recordatorio
        if (isCompany) {
          _goToTab(true, 0);
        } else {
          // Pestaña Calendario del empleado (índice 3).
          _goToTab(false, 3);
        }
        break;
      case 'clock_alert': // fichaje editado / sin fichar / olvidó salida
        // Empresa → pestaña Fichajes (1). Empleado → Mi día (0).
        _goToTab(isCompany, isCompany ? 1 : 0);
        break;
      case 'billing': // empresa: aviso de suscripción
        Get.toNamed(Routes.companySubscription);
        break;
      case 'employee_active': // empresa: un empleado activó su cuenta
        _goToTab(true, 3); // pestaña Empleados
        break;
      case 'employee_deleted': // empleado: su cuenta fue eliminada
        _goToTab(false, 0);
        break;
      case 'report_ready': // reporte mensual de horas disponible
        if (isCompany) {
          Get.toNamed(Routes.companyClockReports);
        } else {
          _goToTab(false, 1); // pestaña Fichajes del empleado
        }
        break;
      default:
        // Sin ruta específica: abre la home según el rol.
        _goToTab(isCompany, 0);
    }
  }

  /// Lleva al usuario a una pestaña concreta del main correspondiente.
  ///
  /// Si el main ya está montado (app abierta), solo cambia el índice de la
  /// pestaña. Si no (app abierta desde la notificación en frío), navega al main
  /// y luego selecciona la pestaña. Índices: 0 Inicio · 1 Fichajes · 2 Chat ·
  /// 3 Empleados(empresa)/Calendario(empleado) · 4 Perfil.
  void _goToTab(bool isCompany, int tabIndex) {
    if (isCompany) {
      if (Get.isRegistered<CompanyMainController>() &&
          Get.currentRoute == Routes.companyMain) {
        Get.find<CompanyMainController>().indexTab.value = tabIndex;
      } else {
        Get.offAllNamed(Routes.companyMain);
        _selectTabWhenReady<CompanyMainController>(
          (c) => c.indexTab.value = tabIndex,
        );
      }
    } else {
      if (Get.isRegistered<EmployeeMainController>() &&
          Get.currentRoute == Routes.employeeMain) {
        Get.find<EmployeeMainController>().indexTab.value = tabIndex;
      } else {
        Get.offAllNamed(Routes.employeeMain);
        _selectTabWhenReady<EmployeeMainController>(
          (c) => c.indexTab.value = tabIndex,
        );
      }
    }
  }

  /// Espera a que el controller del main esté registrado tras navegar y aplica
  /// la selección de pestaña. Reintenta brevemente porque el binding puede no
  /// estar listo en el mismo frame.
  void _selectTabWhenReady<T extends GetxController>(void Function(T) apply) {
    var attempts = 0;
    Timer.periodic(const Duration(milliseconds: 120), (timer) {
      attempts++;
      if (Get.isRegistered<T>()) {
        apply(Get.find<T>());
        timer.cancel();
      } else if (attempts >= 10) {
        timer.cancel();
      }
    });
  }

  String get _platform => Platform.isIOS ? 'ios' : 'android';

  @override
  void onClose() {
    _tokenRefreshSub?.cancel();
    _onMessageSub?.cancel();
    _onMessageOpenedSub?.cancel();
    super.onClose();
  }
}
