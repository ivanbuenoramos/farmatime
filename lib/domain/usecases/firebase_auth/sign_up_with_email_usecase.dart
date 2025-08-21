import 'package:farmatime/domain/repositories/firebase_auth_repository.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignUpWithEmailUseCase {
  final FirebaseAuthRepository repository;

  SignUpWithEmailUseCase(this.repository);

  Future<Result<UserCredential?>> call(String email, String password) {
    return repository.signUpWithEmail(email, password);
  }
}