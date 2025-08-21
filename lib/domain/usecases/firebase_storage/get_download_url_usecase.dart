// use_cases/get_download_url_use_case.dart
import 'package:farmatime/domain/repositories/firebase_storage_repository.dart';

class GetDownloadUrlUseCase {
  final FirebaseStorageRepository repository;

  GetDownloadUrlUseCase(this.repository);

  Future<String> call({required String path, required String fileName}) {
    return repository.getDownloadUrl(path: path, fileName: fileName);
  }
}