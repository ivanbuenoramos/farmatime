import 'dart:io';
import 'package:farmatime/domain/repositories/firebase_storage_repository.dart';

class UpdateFileUseCase {
  final FirebaseStorageRepository repository;

  UpdateFileUseCase(this.repository);

  Future<void> call({
    required File file,
    required String path,
    required String fileName,
    required String existingFileUrl,
  }) {
    return repository.updateFile(
      file: file,
      path: path,
      fileName: fileName,
      existingFileUrl: existingFileUrl,
    );
  }
}