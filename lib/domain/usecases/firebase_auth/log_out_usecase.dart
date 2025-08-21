import 'package:farmatime/domain/repositories/firebase_auth_repository.dart';
import 'package:farmatime/data/models/result.dart';

class LogOutUseCase {
  final FirebaseAuthRepository repository;

  LogOutUseCase(this.repository);

  Future<Result<void>> call() {
    return repository.logOut();
  }
}