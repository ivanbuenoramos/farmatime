import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/firebase_auth_repository.dart';

class DeleteAccountUseCase {
  final FirebaseAuthRepository repository;

  DeleteAccountUseCase(this.repository);

  Future<Result> call() {
    return repository.deleteAccount();
  }
}