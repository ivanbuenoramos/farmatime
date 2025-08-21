import 'package:farmatime/domain/repositories/firebase_auth_repository.dart';

class GetCurrentUserEmailUseCase {
  final FirebaseAuthRepository repository;

  GetCurrentUserEmailUseCase(this.repository);

  String call() {
    return repository.getCurrentUserEmail();
  }
}