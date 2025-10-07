import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/services/toast_service.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/shift_template_repository.dart';
import 'package:farmatime/data/models/shift_template_model.dart';

class ShiftTemplateRepositoryImpl implements ShiftTemplateRepository {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final Brain brain = Brain();
  final ToastService toastService = ToastService();

  /// Colección top-level para turnos de empresa
  CollectionReference<Map<String, dynamic>> _col() =>
      _fs.collection('company_shift_templates');

  @override
  Future<Result<List<ShiftTemplate>>> listByCompany(String companyId) async {
    try {
      final snap = await _col()
          .where('companyId', isEqualTo: companyId)
          .where('active', isEqualTo: true)
          .get()
          .timeout(const Duration(seconds: 10));

      final list = snap.docs
          .map((d) => ShiftTemplate.fromDoc(d.id, d.data()))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      return Result(success: true, data: list);
    } on TimeoutException {
      toastService.showParsedErrorCode('time-exceeded');
      return Result(success: false, data: const [], errorCode: 'time-exceeded');
    } on FirebaseException catch (e) {
      toastService.showParsedErrorCode(e.code);
      return Result(success: false, data: const [], errorCode: e.code);
    } catch (_) {
      toastService.showParsedErrorCode('firestore-error');
      return Result(success: false, data: const [], errorCode: 'firestore-error');
    }
  }

  @override
  Future<Result<String>> upsert(ShiftTemplate template) async {
    try {
      final ref = template.id.isEmpty ? _col().doc() : _col().doc(template.id);
      await ref
          .set({
            ...template.toJson(),
            'updatedAt': FieldValue.serverTimestamp(),
            if (template.id.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));

      return Result(success: true, data: ref.id);
    } on TimeoutException {
      toastService.showParsedErrorCode('time-exceeded');
      return Result(success: false, data: '', errorCode: 'time-exceeded');
    } on FirebaseException catch (e) {
      toastService.showParsedErrorCode(e.code);
      return Result(success: false, data: '', errorCode: e.code);
    } catch (_) {
      toastService.showParsedErrorCode('firestore-error');
      return Result(success: false, data: '', errorCode: 'firestore-error');
    }
  }

  @override
  Future<Result<bool>> delete(String templateId) async {
    try {
      await _col().doc(templateId).delete().timeout(const Duration(seconds: 10));
      return Result(success: true, data: true);
    } on TimeoutException {
      toastService.showParsedErrorCode('time-exceeded');
      return Result(success: false, data: false, errorCode: 'time-exceeded');
    } on FirebaseException catch (e) {
      toastService.showParsedErrorCode(e.code);
      return Result(success: false, data: false, errorCode: e.code);
    } catch (_) {
      toastService.showParsedErrorCode('firestore-error');
      return Result(success: false, data: false, errorCode: 'firestore-error');
    }
  }
}