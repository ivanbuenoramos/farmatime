import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:get_storage/get_storage.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:farmatime/core/app/app.dart';
import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/dependencies.dart';
import 'package:farmatime/core/app/firebase_options.dart';

Future<void> main() async {
  // 1) ¡Siempre lo primero!
  WidgetsFlutterBinding.ensureInitialized();

  // 2) Inicializa Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 3) Inicializa storage y demás utilidades
  await GetStorage.init();

  // 4) Opcional: estilo de barra (ya hay binding)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  // 5) Configura Stripe
  Stripe.publishableKey = 'pk_test_51SD8hCEzO55Y4lolMgZikNXN7qu4AwgLA97yjFi27mB406nt11ELQb28tsoze0IxH7HDgemg90AMPxlC0Px4NIV500rVTZTdV6';
  Stripe.merchantIdentifier = 'merchant.net.farmatime.app';
  Stripe.urlScheme = 'farmatime';
  await Stripe.instance.applySettings();

  // 6) DI una vez Firebase está listo
  DependencyInjection.init();

  // 7) Carga de sesión (si usa GetStorage/Firebase ya está todo listo)
  final brain = Brain();
  await brain.loadSession();

  // 8) Arranca la app
  runApp(const FarmatimeApp());
}