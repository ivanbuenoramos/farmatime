import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:farmatime/core/app/app.dart';
import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/dependencies.dart';
import 'package:farmatime/firebase_options.dart';
import 'package:farmatime/core/services/push_notification_service.dart';

Future<void> main() async {
  // Captura cualquier error no manejado en código async para evitar
  // que la app se cierre en producción sin dejar rastro.
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Errores del framework Flutter (build/layout/paint).
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('🔴 FlutterError: ${details.exceptionAsString()}\n${details.stack}');
    };

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await GetStorage.init();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    DependencyInjection.init();

    final brain = Brain();
    await brain.loadSession();

    // Servicio de notificaciones push (FCM + notificaciones locales).
    // Se registra antes de runApp para que esté disponible vía Get.find, pero
    // se inicializa DESPUÉS del primer frame y sin bloquear: el arranque de la
    // app nunca debe depender del plugin nativo de push (si tarda o se queda
    // colgado esperando el permiso o el mensaje inicial, la UI se pinta igual).
    final pushService = Get.put(PushNotificationService(), permanent: true);

    runApp(const FarmatimeApp());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initPush(pushService, brain));
    });
  }, (Object error, StackTrace stack) {
    debugPrint('🔴 Uncaught zone error: $error\n$stack');
  });
}

/// Inicializa push y, si ya hay sesión, registra el token del usuario actual.
/// Cualquier fallo se registra y no afecta al resto de la app.
Future<void> _initPush(PushNotificationService pushService, Brain brain) async {
  try {
    await pushService.init();
    final loggedUid = brain.employee.value?.uid ?? brain.company.value?.id;
    if (loggedUid != null) {
      await pushService.registerTokenForUser(loggedUid);
    }
  } catch (error, stack) {
    debugPrint('🔴 Push init error: $error\n$stack');
  }
}
