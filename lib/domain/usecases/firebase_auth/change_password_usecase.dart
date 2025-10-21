import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/firebase_auth_repository.dart';



class ChangePasswordUsecase {
  final FirebaseAuthRepository repo;
  ChangePasswordUsecase(this.repo);

  Future<Result<void>> call({
    required String currentPassword,
    required String newPassword,
  }) {
    return repo.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }
}