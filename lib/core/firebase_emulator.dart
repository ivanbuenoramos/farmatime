import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Conexión opcional al Firebase Emulator Suite, SOLO para QA/desarrollo.
///
/// Se activa con `--dart-define=FIREBASE_EMULATOR_HOST=<host>` (`localhost`
/// en el simulador iOS, `10.0.2.2` en el emulador Android). Sin ese define, y
/// siempre en builds release, la clase es inerte y la app habla con producción.
class FirebaseEmulator {
  const FirebaseEmulator._();

  static const String host = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
  static const String projectId = 'farmatime-app';
  static const String region = 'europe-west1';
  static const int authPort = 9099;
  static const int firestorePort = 8080;
  static const int functionsPort = 5001;
  static const int storagePort = 9199;

  /// Nunca en release aunque alguien pase el define por error.
  static bool get enabled => host.isNotEmpty && !kReleaseMode;

  /// URL de una Cloud Function callable (v2) servida por el emulador.
  static Uri callableUri(String functionName) =>
      Uri.http('$host:$functionsPort', '/$projectId/$region/$functionName');

  /// Debe llamarse justo después de `Firebase.initializeApp` y antes de usar
  /// cualquier servicio de Firebase.
  static bool _connected = false;

  static Future<void> connectIfEnabled() async {
    if (!enabled || _connected) return;
    _connected = true;
    await FirebaseAuth.instance.useAuthEmulator(host, authPort);
    FirebaseFirestore.instance.useFirestoreEmulator(host, firestorePort);
    await FirebaseStorage.instance.useStorageEmulator(host, storagePort);
    FirebaseFunctions.instanceFor(region: region)
        .useFunctionsEmulator(host, functionsPort);
    debugPrint(
      '⚙️ Firebase Emulator Suite: $host '
      '(auth $authPort · firestore $firestorePort · functions $functionsPort · storage $storagePort)',
    );
  }
}
