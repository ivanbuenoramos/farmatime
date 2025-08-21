import 'package:farmatime/core/app/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:get_storage/get_storage.dart';

import 'package:farmatime/core/app/app.dart';
import 'package:farmatime/core/dependencies.dart';
import 'package:farmatime/core/app/brain.dart';


void main() async {

  final Brain brain = Brain();

  await GetStorage.init();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );
  
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  DependencyInjection.init();
  
  await brain.loadSession();


  runApp(const FarmatimeApp());
}