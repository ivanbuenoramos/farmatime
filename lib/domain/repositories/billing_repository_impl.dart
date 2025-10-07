import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/billing/billing_models.dart';
import 'package:farmatime/data/repositories/billing_repository.dart';



class BillingRepositoryImpl implements BillingRepository {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _companyDoc(String companyId) =>
      _fs.collection('companies').doc(companyId);

  @override
  Future<Result<CompanyBilling?>> getCompanyBilling(String companyId) async {
    try {
      final snap = await _companyDoc(companyId).get();
      if (!snap.exists) {
        return Result(success: true, data: null);
      }
      final data = snap.data()!;
      final billing = CompanyBilling.fromJson(snap.id, data);
      return Result(success: true, data: billing);
    } catch (e) {
      return Result(success: false, data: null, errorCode: e.toString());
    }
  }

  @override
  Stream<CompanyBilling?> watchCompanyBilling(String companyId) {
    return _companyDoc(companyId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return CompanyBilling.fromJson(doc.id, doc.data()!);
    });
  }

  @override
  Future<Result<void>> updateOccupiedSeats(String companyId, int occupiedSeats) async {
    try {
      await _companyDoc(companyId).set({
        'occupiedSeats': occupiedSeats,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return Result(success: true, data: null);
    } catch (e) {
      return Result(success: false, data: null, errorCode: e.toString());
    }
  }
}