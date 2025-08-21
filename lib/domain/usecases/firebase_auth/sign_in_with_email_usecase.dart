import 'package:farmatime/domain/repositories/firebase_auth_repository.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignInWithEmailUseCase {
  final FirebaseAuthRepository repository;

  SignInWithEmailUseCase(this.repository);

  Future<Result<UserCredential?>> call(String email, String password) {
    return repository.signInWithEmail(email, password);
  }
}