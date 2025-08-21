
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/firebase_auth_repository.dart';

class ReauthenticateUseCase {
  final FirebaseAuthRepository repository;

  ReauthenticateUseCase(this.repository);

  Future<Result> call(String email, String password) {
    return repository.reauthenticate(email, password);
  }
}