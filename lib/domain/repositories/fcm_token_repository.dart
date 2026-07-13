import 'package:farmatime/data/models/result.dart';

/// Gestiona los tokens de Firebase Cloud Messaging asociados a un usuario
/// (empresa o empleado). Los tokens se guardan en Firestore para que el
/// backend pueda dirigir notificaciones push a los dispositivos del usuario.
///
/// Esquema en Firestore:
///   user_fcm_tokens/{uid}/tokens/{token}
///     - token: String        (el propio FCM registration token)
///     - platform: String     ('ios' | 'android')
///     - updatedAt: Timestamp  (última vez que se vio activo)
///   user_fcm_tokens/{uid}   (doc padre)
///     - prefs: `Map<String,bool>`  preferencias de push del usuario; las
///       consulta el backend (sendPush.js) antes de enviar. Sin doc/campo =
///       todo activado.
abstract class FcmTokenRepository {
  /// Registra o refresca el [token] del usuario [uid]. Idempotente: si ya
  /// existe solo actualiza `updatedAt`.
  Future<Result<bool>> saveToken({
    required String uid,
    required String token,
    required String platform,
  });

  /// Elimina un [token] concreto del usuario [uid]. Se usa al cerrar sesión
  /// en este dispositivo.
  Future<Result<bool>> deleteToken({
    required String uid,
    required String token,
  });

  /// Guarda las preferencias de push del usuario [uid] para que el backend
  /// las respete al enviar. Claves esperadas: pushEnabled, leaveRequests,
  /// leaveStatusUpdates, scheduleChanges, chatMessages.
  Future<Result<bool>> savePushPrefs({
    required String uid,
    required Map<String, bool> prefs,
  });

  /// Lee las preferencias guardadas. `data == null` si nunca se han guardado
  /// (equivale a todo activado).
  Future<Result<Map<String, bool>?>> loadPushPrefs({required String uid});
}
