import 'package:firebase_auth/firebase_auth.dart';
import 'package:farmatime/data/models/result.dart';

abstract class FirebaseAuthRepository {
  Future<Result<UserCredential?>> signInWithEmail(String email, String password);
  Future<Result<UserCredential?>> signUpWithEmail(String email, String password);
  Future<Result<void>> sendPasswordResetEmail(String email);
  Future<Result<void>> logOut();
  String getCurrentUserEmail();
  Future<Result<bool>> checkEmailVerification();
  Future<Result<void>> sendEmailVerification();
  Future<Result> deleteAccount();
  Future<Result> reauthenticate(String email, String password);
  Future<Result<String?>> checkUserExistsByEmail(String email);
}
