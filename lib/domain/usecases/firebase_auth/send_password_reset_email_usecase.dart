import 'package:farmatime/domain/repositories/firebase_auth_repository.dart';
import 'package:farmatime/data/models/result.dart';

class SendPasswordResetEmailUseCase {
  final FirebaseAuthRepository repository;

  SendPasswordResetEmailUseCase(this.repository);

  Future<Result<void>> call(String email) {
    return repository.sendPasswordResetEmail(email);
  }
}