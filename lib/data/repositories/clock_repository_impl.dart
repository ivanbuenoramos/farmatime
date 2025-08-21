import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:farmatime/data/models/clock_in_out_model.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/clock_repository.dart';

class ClockRepositoryImpl implements ClockRepository {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  Future<Result<ClockInOutModel?>> createEntry(ClockInOutModel entry) async {
    try {
      final docRef = firestore.collection('clockRecords').doc(entry.id);
      final newEntry = entry.copyWith(id: docRef.id);
      await docRef.set(newEntry.toJson());
      return Result(success: true, data: newEntry);
    } catch (e) {
      return Result(success: false, data: null, errorCode: e.toString());
    }
  }

  @override
  Future<Result<ClockInOutModel?>> getCurrentEntry(String employeeId) async {
    try {
      final query = await firestore
          .collection('clockRecords')
          .where('employeeId', isEqualTo: employeeId)
          .where('clockOut', isNull: true)
          .orderBy('clockIn', descending: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return Result(success: true, data: null);
      }

      final entry = ClockInOutModel.fromJson(query.docs.first.data());
      return Result(success: true, data: entry);
    } catch (e) {
      return Result(success: false, data: null, errorCode: e.toString());
    }
  }

  @override
  Future<Result<List<ClockInOutModel>>> getEntriesByEmployee(String employeeId) async {
    try {
      final query = await firestore
          .collection('clockRecords')
          .where('employeeId', isEqualTo: employeeId)
          .orderBy('clockIn', descending: true)
          .get();

      final entries = query.docs.map((doc) => ClockInOutModel.fromJson(doc.data())).toList();
      return Result(success: true, data: entries);
    } catch (e) {
      return Result(success: false, data: [], errorCode: e.toString());
    }
  }

  @override
  Future<Result<ClockInOutModel?>> updateEntry(ClockInOutModel entry) async {
    try {
      await firestore.collection('clockRecords').doc(entry.id).update(entry.toJson());
      return Result(success: true, data: entry);
    } catch (e) {
      return Result(success: false, data: null, errorCode: e.toString());
    }
  }

  @override
  Future<Result<Map<String, ClockInOutModel>>> getLatestEntriesByCompanyInRange(
    String companyId,
    DateTime from,
    DateTime to,
  ) async {
    try {
      final snap = await firestore
          .collection('clockRecords')
          .where('companyId', isEqualTo: companyId)
          .where('clockIn', isGreaterThanOrEqualTo: from.toIso8601String())
          .where('clockIn', isLessThanOrEqualTo: to.toIso8601String())
          .orderBy('clockIn', descending: true)
          .get();

      final map = <String, ClockInOutModel>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final rec = ClockInOutModel.fromJson(data);
        // si ya tenemos ese empleado, ignoramos (ya añadimos el más reciente)
        if (!map.containsKey(rec.employeeId)) {
          map[rec.employeeId] = rec;
        }
      }
      return Result(success: true, data: map);
    } catch (e) {
      return Result(success: false, data: {}, errorCode: e.toString());
    }
  }
}
