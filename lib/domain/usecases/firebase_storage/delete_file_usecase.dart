// use_cases/delete_file_use_case.dart
import 'package:farmatime/domain/repositories/firebase_storage_repository.dart';

class DeleteFileUseCase {
  final FirebaseStorageRepository repository;

  DeleteFileUseCase(this.repository);

  Future<void> call({required String fileUrl}) {
    return repository.deleteFile(fileUrl: fileUrl);
  }
}