import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/fcm_token_repository.dart';

class FcmTokenRepositoryImpl implements FcmTokenRepository {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  static const String _root = 'user_fcm_tokens';
  static const String _tokens = 'tokens';

  @override
  Future<Result<bool>> saveToken({
    required String uid,
    required String token,
    required String platform,
  }) async {
    try {
      // El propio token como id del doc evita duplicados del mismo dispositivo.
      await firestore
          .collection(_root)
          .doc(uid)
          .collection(_tokens)
          .doc(token)
          .set({
        'token': token,
        'platform': platform,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return Result(success: true, data: true);
    } catch (e) {
      developer.log('saveToken error', name: 'FcmTokenRepository', error: e);
      return Result(success: false, data: false, errorCode: e.toString());
    }
  }

  @override
  Future<Result<bool>> deleteToken({
    required String uid,
    required String token,
  }) async {
    try {
      await firestore
          .collection(_root)
          .doc(uid)
          .collection(_tokens)
          .doc(token)
          .delete();
      return Result(success: true, data: true);
    } catch (e) {
      developer.log('deleteToken error', name: 'FcmTokenRepository', error: e);
      return Result(success: false, data: false, errorCode: e.toString());
    }
  }

  @override
  Future<Result<bool>> savePushPrefs({
    required String uid,
    required Map<String, bool> prefs,
  }) async {
    try {
      await firestore.collection(_root).doc(uid).set({
        'prefs': prefs,
        'prefsUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return Result(success: true, data: true);
    } catch (e) {
      developer.log('savePushPrefs error',
          name: 'FcmTokenRepository', error: e);
      return Result(success: false, data: false, errorCode: e.toString());
    }
  }

  @override
  Future<Result<Map<String, bool>?>> loadPushPrefs({
    required String uid,
  }) async {
    try {
      final doc = await firestore.collection(_root).doc(uid).get();
      final raw = doc.data()?['prefs'];
      if (raw is! Map) return Result(success: true, data: null);
      final prefs = <String, bool>{
        for (final e in raw.entries)
          if (e.value is bool) e.key.toString(): e.value as bool,
      };
      return Result(success: true, data: prefs);
    } catch (e) {
      developer.log('loadPushPrefs error',
          name: 'FcmTokenRepository', error: e);
      return Result(success: false, data: null, errorCode: e.toString());
    }
  }
}
