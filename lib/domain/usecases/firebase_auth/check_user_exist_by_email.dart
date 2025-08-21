import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/firebase_auth_repository.dart';

class CheckUserExistsByEmailUseCase {
  final FirebaseAuthRepository repository;

  CheckUserExistsByEmailUseCase(this.repository);

  Future<Result<String?>> call(String email) {
    return repository.checkUserExistsByEmail(email);
  }
}