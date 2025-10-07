import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/company_subscription.dart';
import 'package:farmatime/domain/repositories/subscription_repository.dart';



class SubscriptionRepositoryImpl implements SubscriptionRepository {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String companyId) =>
      _fs.collection('companies').doc(companyId).collection('subscription').doc('current');

  @override
  Future<Result<CompanySubscription?>> getCurrent(String companyId) async {
    try {
      final snap = await _doc(companyId).get();
      if (!snap.exists) {
        // Puedes devolver null o crear un default “1€/seat”
        return Result(success: true, data: null);
      }
      final sub = CompanySubscription.fromJson(snap.data()!);
      return Result(success: true, data: sub);
    } on FirebaseException catch (e) {
      return Result(success: false, data: null, errorCode: e.code);
    } catch (e) {
      return Result(success: false, data: null, errorCode: 'unknown-error');
    }
  }

  @override
  Future<Result<void>> upsert(String companyId, CompanySubscription sub) async {
    try {
      await _doc(companyId).set(sub.toJson(), SetOptions(merge: true));
      return Result(success: true, data: null);
    } on FirebaseException catch (e) {
      return Result(success: false, data: null, errorCode: e.code);
    } catch (e) {
      return Result(success: false, data: null, errorCode: 'unknown-error');
    }
  }

  @override
  Future<Result<void>> updateStatus(String companyId, SubscriptionStatus status) async {
    try {
      await _doc(companyId).set({
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return Result(success: true, data: null);
    } on FirebaseException catch (e) {
      return Result(success: false, data: null, errorCode: e.code);
    } catch (e) {
      return Result(success: false, data: null, errorCode: 'unknown-error');
    }
  }

  @override
  Future<Result<void>> updateNextRenewal(String companyId, DateTime date) async {
    try {
      await _doc(companyId).set({
        'nextRenewal': Timestamp.fromDate(date),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return Result(success: true, data: null);
    } on FirebaseException catch (e) {
      return Result(success: false, data: null, errorCode: e.code);
    } catch (e) {
      return Result(success: false, data: null, errorCode: 'unknown-error');
    }
  }
}