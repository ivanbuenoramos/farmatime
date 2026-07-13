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
    final pushService = Get.put(PushNotificationService(), permanent: true);
    await pushService.init();
    // Si ya hay sesión iniciada, refrescamos el token para el usuario actual.
    final loggedUid = brain.employee.value?.uid ?? brain.company.value?.id;
    if (loggedUid != null) {
      await pushService.registerTokenForUser(loggedUid);
    }

    runApp(const FarmatimeApp());
  }, (Object error, StackTrace stack) {
    debugPrint('🔴 Uncaught zone error: $error\n$stack');
  });
}
