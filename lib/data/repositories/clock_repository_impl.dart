import 'dart:async';

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
      final fromWindow = from.subtract(const Duration(days: 1)); // 👈 ventana previa
      final snap = await firestore
          .collection('clockRecords')
          .where('companyId', isEqualTo: companyId)
          .where('clockIn', isGreaterThanOrEqualTo: fromWindow)
          .where('clockIn', isLessThanOrEqualTo: to)
          .orderBy('clockIn', descending: true)
          .get();

      final map = <String, ClockInOutModel>{};

      for (final doc in snap.docs) {
        final rec = ClockInOutModel.fromJson(doc.data());

        final bool dentroDeHoy =
            (rec.clockIn.isAtSameMomentAs(from) || rec.clockIn.isAfter(from)) &&
            (rec.clockIn.isBefore(to) || rec.clockIn.isAtSameMomentAs(to));

        final bool abiertoDeAyer =
            rec.clockIn.isBefore(from) && rec.clockOut == null;

        if ((dentroDeHoy || abiertoDeAyer) && !map.containsKey(rec.employeeId)) {
          map[rec.employeeId] = rec; // al ir descendente es el último relevante
        }
      }

      return Result(success: true, data: map);
    } catch (e) {
      return Result(success: false, data: {}, errorCode: e.toString());
    }
  }

  @override
  Future<List<ClockInOutModel>> getClockRecords({
    required String companyId,
    required DateTime from,
    required DateTime to,
    String? employeeId,
  }) async {
    Query col = firestore
        .collection('clockRecords')
        .where('companyId', isEqualTo: companyId)
        .where('clockIn', isGreaterThanOrEqualTo: from)
        .where('clockIn', isLessThanOrEqualTo: to);

    if (employeeId != null) {
      col = col.where('employeeId', isEqualTo: employeeId);
    }

    final snap = await col.orderBy('clockIn', descending: true).get();

    return snap.docs
        .map(
          (d) => ClockInOutModel.fromJson(
            d.data() as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  @override
  Future<List<ClockInOutModel>> getClockRecordsForEmployeeDay({
    required String companyId,
    required String employeeId,
    required DateTime day,
  }) async {
    final fromDay = DateTime(day.year, day.month, day.day, 0, 0, 0);
    final toDay =
        DateTime(day.year, day.month, day.day, 23, 59, 59, 999);

    final snap = await firestore
        .collection('clockRecords')
        .where('companyId', isEqualTo: companyId)
        .where('employeeId', isEqualTo: employeeId)
        .where('clockIn', isGreaterThanOrEqualTo: fromDay)
        .where('clockIn', isLessThanOrEqualTo: toDay)
        .orderBy('clockIn')
        .get();

    return snap.docs
        .map(
          (d) => ClockInOutModel.fromJson(
            d.data(),
          ),
        )
        .toList();
  }

  @override
  Stream<List<ClockInOutModel>> streamClockRecords({
    required String companyId,
    required DateTime from,
    required DateTime to,
    String? employeeId,
  }) {
    // 🔧 Cambia 'clockRecords' por tu colección real
    Query<Map<String, dynamic>> q = firestore
        .collection('clockRecords')
        .where('companyId', isEqualTo: companyId)
        // asumo que guardas clockIn como Timestamp
        .where('clockIn', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('clockIn', isLessThanOrEqualTo: Timestamp.fromDate(to))
        .orderBy('clockIn', descending: false);

    if (employeeId != null && employeeId.isNotEmpty) {
      q = q.where('employeeId', isEqualTo: employeeId);
    }

    return q.snapshots().map((snap) {
      return snap.docs.map((d) {
        final data = d.data();

        // Ideal: forzar uid = id doc
        // Si tu ClockInOutModel no tiene copyWith(uid:), ajusta tu model.
        final model = ClockInOutModel.fromJson(data);
        try {
          return model.copyWith(id: d.id); // o uid: d.id según tu modelo
        } catch (_) {
          return model;
        }
      }).toList();
    });
  }

  @override
  Stream<Map<String, (DateTime? lastClockIn, bool isActive)>> streamTodayLastClocks(
    String companyId,
    DateTime from,
    DateTime to, {
    List<String>? employeeIds, // si >10 se ignora (como tú querías)
  }) {
    // Query de HOY (por clockIn)
    Query<Map<String, dynamic>> qToday = firestore
        .collection('clockRecords')
        .where('companyId', isEqualTo: companyId)
        .where('clockIn', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('clockIn', isLessThanOrEqualTo: Timestamp.fromDate(to))
        .orderBy('clockIn', descending: false);

    // Query de ABIERTOS (clockOut == null) => incluye los de ayer
    // Ojo: isNull existe en Firestore y es lo que quieres.
    Query<Map<String, dynamic>> qOpen = firestore
        .collection('clockRecords')
        .where('companyId', isEqualTo: companyId)
        .where('clockOut', isNull: true);

    // Si quieres acotar un poco (recomendado): solo abiertos “recientes”
    // qOpen = qOpen.where('clockIn', isLessThanOrEqualTo: Timestamp.fromDate(to));

    // whereIn máx 10: si te pasan <=10, filtra. Si >10, se ignora.
    if (employeeIds != null && employeeIds.isNotEmpty && employeeIds.length <= 10) {
      qToday = qToday.where('employeeId', whereIn: employeeIds);
      qOpen = qOpen.where('employeeId', whereIn: employeeIds);
    }

    final controller = StreamController<Map<String, (DateTime?, bool)>>.broadcast();

    Map<String, (DateTime?, bool)> lastToday = {};
    Map<String, (DateTime?, bool)> lastOpen = {};

    StreamSubscription? subToday;
    StreamSubscription? subOpen;

    void emitMerged() {
      // merge: abiertos pisan a hoy (porque si está abierto, es working sí o sí)
      final merged = <String, (DateTime?, bool)>{};
      merged.addAll(lastToday);
      merged.addAll(lastOpen);
      if (!controller.isClosed) controller.add(merged);
    }

    void attach() {
      subToday = qToday.snapshots().listen((snap) {
        final lastByEmployee = <String, Map<String, dynamic>>{};

        for (final d in snap.docs) {
          final data = d.data();
          final empId = (data['employeeId'] ?? '').toString();
          if (empId.isEmpty) continue;

          // Como viene ordenado por clockIn ASC, el último pisa al anterior
          lastByEmployee[empId] = data;
        }

        final out = <String, (DateTime?, bool)>{};
        for (final e in lastByEmployee.entries) {
          final data = e.value;

          final ci = data['clockIn'];
          DateTime? clockIn;
          if (ci is Timestamp) clockIn = ci.toDate();
          else if (ci is DateTime) clockIn = ci;

          // 🔥 isActive basado en RAW: si no hay clockOut o es null
          final isActive = data['clockOut'] == null;

          out[e.key] = (clockIn, isActive);
        }

        lastToday = out;
        emitMerged();
      }, onError: (e) {
        // si falla uno, no rompas el otro
        if (!controller.isClosed) controller.addError(e);
      });

      subOpen = qOpen.snapshots().listen((snap) {
        // En abiertos puede haber 1 por empleado (ideal).
        // Si hay varios (incoherencia), nos quedamos con el último por clockIn.
        final best = <String, Map<String, dynamic>>{};
        final bestMillis = <String, int>{};

        for (final d in snap.docs) {
          final data = d.data();
          final empId = (data['employeeId'] ?? '').toString();
          if (empId.isEmpty) continue;

          final ci = data['clockIn'];
          int millis = 0;
          if (ci is Timestamp) millis = ci.millisecondsSinceEpoch;
          else if (ci is DateTime) millis = ci.millisecondsSinceEpoch;

          final prev = bestMillis[empId] ?? -1;
          if (millis >= prev) {
            bestMillis[empId] = millis;
            best[empId] = data;
          }
        }

        final out = <String, (DateTime?, bool)>{};
        for (final e in best.entries) {
          final data = e.value;

          final ci = data['clockIn'];
          DateTime? clockIn;
          if (ci is Timestamp) clockIn = ci.toDate();
          else if (ci is DateTime) clockIn = ci;

          // abiertos => activo sí o sí (y además raw clockOut null)
          out[e.key] = (clockIn, true);
        }

        lastOpen = out;
        emitMerged();
      }, onError: (e) {
        if (!controller.isClosed) controller.addError(e);
      });

      controller.onCancel = () async {
        await subToday?.cancel();
        await subOpen?.cancel();
        await controller.close();
      };
    }

    attach();
    return controller.stream;
  }
}
