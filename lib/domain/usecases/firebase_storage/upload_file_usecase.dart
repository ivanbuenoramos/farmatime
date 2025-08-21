// use_cases/upload_file_use_case.dart
import 'dart:io';
import 'package:farmatime/domain/repositories/firebase_storage_repository.dart';

class UploadFileUseCase {
  final FirebaseStorageRepository repository;

  UploadFileUseCase(this.repository);

  Future<String?> call({
    required File file,
    required String path,
    required String fileName,
  }) {
    return repository.uploadFile(file: file, path: path, fileName: fileName);
  }
}