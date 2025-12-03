import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/services/toast_service.dart';
import 'package:farmatime/domain/repositories/firebase_auth_repository.dart';



class FirebaseAuthRepositoryImpl implements FirebaseAuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Brain brain = Brain();
  final ToastService toastService = ToastService();

  @override
  Future<Result<UserCredential?>> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 10));

      final uid = credential.user?.uid;
      if (uid == null) throw FirebaseAuthException(code: 'user-not-found');

      return Result(success: true, data: credential);
    } on TimeoutException {
      toastService.showParsedErrorCode('time-exceeded');
      return Result(success: false, data: null, errorCode: 'time-exceeded');
    } on FirebaseAuthException catch (e) {
      toastService.showParsedErrorCode(e.code);
      return Result(success: false, data: null, errorCode: e.code);
    } catch (e) {
      toastService.showParsedErrorCode('auth-error');
      return Result(success: false, data: null, errorCode: 'auth-error');
    }
  }


  @override
  Future<Result<UserCredential?>> signUpWithEmail(String email, String password) async {
    try {
      final credential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 10));
      return Result(success: true, data: credential);
    } on TimeoutException {
      toastService.showParsedErrorCode('time-exceeded');
      return Result(success: false, data: null, errorCode: 'time-exceeded');
    } on FirebaseException catch (e) {
      toastService.showParsedErrorCode(e.code);
      return Result(success: false, data: null, errorCode: e.code);
    } catch (e) {
      toastService.showParsedErrorCode('auth-error');
      return Result(success: false, data: null, errorCode: 'auth-error');
    }
  }

  @override
  Future<Result<void>> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      toastService.show(
        title: 'Correo enviado',
        message: 'Revisa tu correo para restablecer la contraseña.',
        type: ToastType.success,
      );
      return Result(success: true, data: null);
    } on FirebaseAuthException catch (e) {
      toastService.showParsedErrorCode(e.code);
      return Result(success: false, data: null, errorCode: e.code);
    } catch (e) {
      toastService.showParsedErrorCode('auth-error');
      return Result(success: false, data: null, errorCode: 'auth-error');
    }
  }

  @override
  Future<Result<void>> logOut() async {
    try {
      await _auth.signOut();
      return Result(success: true, data: null);
    } catch (e) {
      return Result(success: false, data: null);
    }
  }

  @override
  String getCurrentUserEmail() {
    final user = _auth.currentUser;
    if (user != null && user.email != null) {
      return user.email!;
    } else {
      throw Exception("No authenticated user found.");
    }
  }

  @override
  Future<Result<bool>> checkEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return Result(success: false, errorCode: 'user-not-found', data: false);
      }
      await user.reload();
      return Result(success: true, data: user.emailVerified);
    } on FirebaseAuthException catch (e) {
      return Result(success: false, errorCode: e.code, data: false);
    } catch (e) {
      return Result(success: false, errorCode: 'auth-error', data: false);
    }
  }

  @override
  Future<Result<void>> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        toastService.show(
          title: 'Correo de verificación enviado',
          message: 'Revisa tu correo para verificar tu cuenta.',
          type: ToastType.success,
        );
        return Result(success: true, data: null);
      } else if (user == null) {
        toastService.show(
          title: 'Error',
          message: 'No hay un usuario autenticado.',
          type: ToastType.error,
        );
        return Result(success: false, data: null, errorCode: 'user-not-found');
      } else {
        toastService.show(
          title: 'Error',
          message: 'El correo ya está verificado.',
          type: ToastType.warning,
        );
        return Result(success: false, data: null, errorCode: 'already-verified');
      }
    } on FirebaseAuthException catch (e) {
      toastService.showParsedErrorCode(e.code);
      return Result(success: false, data: null, errorCode: e.code);
    } catch (e) {
      toastService.showParsedErrorCode('auth-error');
      return Result(success: false, data: null, errorCode: 'auth-error');
    }
  }

  @override
  Future<Result> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return Result(success: false, data: null);
      await user.delete();
      return Result(success: true, data: null);
    } catch (e) {
      print(e);
      return Result(success: false, data: null);
    }
  }

  @override
  Future<Result> reauthenticate(String email, String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return Result(success: false, data: null);
      final cred = EmailAuthProvider.credential(email: email, password: password);
      await user.reauthenticateWithCredential(cred);
      return Result(success: true, data: null);
    } on FirebaseAuthException catch (e) {
      return Result(success: false, data: null, errorCode: e.code);
    } catch (e) {
      return Result(success: false, data: null, errorCode: 'unknown-error');
    }
  }

  @override
  Future<Result<String?>> checkUserExistsByEmail(String email) async {
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      return Result(success: true, data: methods.isNotEmpty ? 'Email exists' : null);
    } on FirebaseAuthException catch (e) {
      return Result(success: false, data: null, errorCode: e.code);
    } catch (e) {
      return Result(success: false, data: null, errorCode: 'unknown-error');
    }
  }

  @override
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return Result(success: false, data: null, errorCode: 'user-not-found');
      }
      if (newPassword.length < 6) {
        return Result(success: false, data: null, errorCode: 'weak-password');
      }
      final email = user.email;
      if (email == null) {
        return Result(success: false, data: null, errorCode: 'email-not-found');
      }
      final cred = EmailAuthProvider.credential(email: email, password: currentPassword);
      await user.reauthenticateWithCredential(cred).timeout(const Duration(seconds: 10));
      await user.updatePassword(newPassword).timeout(const Duration(seconds: 10));
      return Result(success: true, data: null);
    } on TimeoutException {
      toastService.showParsedErrorCode('time-exceeded');
      return Result(success: false, data: null, errorCode: 'time-exceeded');
    } on FirebaseAuthException catch (e) {
      // Reutiliza tu parser para mostrar toasts amigables
      toastService.showParsedErrorCode(e.code);
      return Result(success: false, data: null, errorCode: e.code);
    } catch (e) {
      toastService.showParsedErrorCode('auth-error');
      return Result(success: false, data: null, errorCode: 'auth-error');
    }
  }
}
