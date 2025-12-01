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
  WidgetsFlutterBinding.ensureInitialized();
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

  Stripe.publishableKey = 'pk_test_51SD8hCEzO55Y4lolMgZikNXN7qu4AwgLA97yjFi27mB406nt11ELQb28tsoze0IxH7HDgemg90AMPxlC0Px4NIV500rVTZTdV6';
  Stripe.merchantIdentifier = 'merchant.net.farmatime.app';
  Stripe.urlScheme = 'farmatime';
  await Stripe.instance.applySettings();

  DependencyInjection.init();

  final brain = Brain();
  await brain.loadSession();

  runApp(const FarmatimeApp());
}