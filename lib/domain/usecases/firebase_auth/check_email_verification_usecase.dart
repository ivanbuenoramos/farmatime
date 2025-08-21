
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/firebase_auth_repository.dart';

class CheckEmailVerificationUseCase {
  final FirebaseAuthRepository repository;

  CheckEmailVerificationUseCase(this.repository);

  Future<Result<bool>> call() {
    return repository.checkEmailVerification();
  }
}