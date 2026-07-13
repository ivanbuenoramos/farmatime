import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

/// Error de una llamada callable: lleva el mensaje y código que devolvió la
/// Cloud Function (protocolo callable: `{"error":{"message","status"}}`),
/// equivalente a FirebaseFunctionsException. Capturar con try/catch.
class CallableException implements Exception {
  final String message;
  final String? status;
  final int httpStatus;

  CallableException(this.message, {this.status, required this.httpStatus});

  @override
  String toString() =>
      'CallableException(${status ?? httpStatus}): $message';
}

/// Invoca una Cloud Function callable (v2) por HTTP directo siguiendo el
/// protocolo callable: POST {"data": ...} → {"result": ...}.
///
/// Existe para esquivar un crash nativo del SDK FirebaseFunctions de iOS:
/// en builds de release, HTTPSCallable.SendableHTTPSCallable.call aborta el
/// proceso (swift_Concurrency_fatalError en asyncLet_finish_after_task_
/// completion). Confirmado en FirebaseFunctions 11.15.0 con los crashlogs
/// del 2026-06-09 (incidentes 673C6B76 y 4C334949). Mientras el SDK nativo
/// no esté arreglado, las llamadas hechas con esta clase no pueden tirar
/// la app: cualquier fallo sale como excepción Dart capturable.
class CallableHttpClient {
  static const _region = 'europe-west1';
  static const _projectId = 'farmatime-app';

  /// Llama a [functionName] con [data] y devuelve el contenido de "result"
  /// (equivalente a `HttpsCallableResult.data`).
  /// Lanza [CallableException] si la función responde con error (con el
  /// mensaje real del backend). [timeout] limita la operación completa.
  static Future<dynamic> call(
    String functionName,
    Map<String, dynamic> data, {
    Duration timeout = const Duration(seconds: 70),
  }) async {
    return _call(functionName, data).timeout(timeout);
  }

  static Future<dynamic> _call(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    Uri uri = Uri.https(
      '$_region-$_projectId.cloudfunctions.net',
      '/$functionName',
    );

    final payload = utf8.encode(json.encode({'data': data}));
    // El ID token rellena request.auth en la Cloud Function callable.
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      // Manejamos los redirects manualmente: las funciones gen2 pueden
      // redirigir cloudfunctions.net → run.app, y el auto-redirect de
      // HttpClient convierte el POST en GET (perdería body y auth).
      for (var redirects = 0; redirects < 5; redirects++) {
        final request = await client.postUrl(uri);
        request.followRedirects = false;
        request.headers.contentType = ContentType.json;
        if (token != null) {
          request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
        }
        request.add(payload);

        final response = await request.close();

        if (response.isRedirect) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          await response.drain<void>();
          if (location == null) {
            throw CallableException(
              'Redirect sin Location',
              httpStatus: response.statusCode,
            );
          }
          uri = uri.resolve(location);
          continue;
        }

        final body = await response.transform(utf8.decoder).join();

        if (response.statusCode < 200 || response.statusCode >= 300) {
          // Protocolo callable de error: {"error":{"message","status"}}.
          String message = body;
          String? status;
          try {
            final decoded = json.decode(body);
            final err = decoded is Map ? decoded['error'] : null;
            if (err is Map) {
              message = (err['message'] ?? body).toString();
              status = err['status']?.toString();
            }
          } catch (_) {}
          throw CallableException(
            message,
            status: status,
            httpStatus: response.statusCode,
          );
        }

        final decoded = json.decode(body);
        return decoded is Map<String, dynamic> ? decoded['result'] : null;
      }
      throw CallableException('Demasiados redirects', httpStatus: 0);
    } finally {
      client.close();
    }
  }
}
