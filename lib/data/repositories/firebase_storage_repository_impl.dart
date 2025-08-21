// firebase_storage_repository_impl.dart
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:farmatime/domain/repositories/firebase_storage_repository.dart';

class FirebaseStorageRepositoryImpl implements FirebaseStorageRepository {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  Future<String> uploadFile({
    required File file,
    required String path,
    required String fileName,
  }) async {
    try {
      final Reference storageRef = _storage.ref().child('$path/$fileName');
      final UploadTask uploadTask = storageRef.putFile(file);
      await uploadTask.whenComplete(() {});
      final String downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteFile({required String fileUrl}) async {
    try {
      final Reference storageRef = _storage.refFromURL(fileUrl);
      await storageRef.delete();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<String> getDownloadUrl({
    required String path,
    required String fileName,
  }) async {
    try {
      final Reference storageRef = _storage.ref().child('$path/$fileName');
      final String downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateFile({
    required File file,
    required String path,
    required String fileName,
    required String existingFileUrl,
  }) async {
    try {
      // Delete the existing file
      await deleteFile(fileUrl: existingFileUrl);

      // Upload the new file
      await uploadFile(file: file, path: path, fileName: fileName);
    } catch (e) {
      rethrow;
    }
  }
}