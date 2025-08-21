import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/firebase_auth_repository.dart';

class SendEmailVerificationUseCase {
  final FirebaseAuthRepository repository;

  SendEmailVerificationUseCase(this.repository);

  Future<Result<void>> call() {
    return repository.sendEmailVerification();
  }
}