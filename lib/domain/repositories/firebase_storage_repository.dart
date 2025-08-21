import 'dart:io';

abstract class FirebaseStorageRepository {
  Future<String> uploadFile({
    required File file,
    required String path,
    required String fileName,
  });

  Future<void> deleteFile({required String fileUrl});

  Future<String> getDownloadUrl({required String path, required String fileName});

  Future<void> updateFile({
    required File file,
    required String path,
    required String fileName,
    required String existingFileUrl,
  });
}