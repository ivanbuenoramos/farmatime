import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:farmatime/core/services/toast_service.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/schedule/day_entry.dart';
import 'package:farmatime/data/models/schedule/time_off_model.dart';
import 'package:farmatime/domain/repositories/time_off_repository.dart';

class TimeOffRepositoryImpl implements TimeOffRepository {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final ToastService toastService = ToastService();

  CollectionReference<Map<String, dynamic>> _col() =>
      _fs.collection('time_off_requests');

  CollectionReference<Map<String, dynamic>> _monthsCol() =>
      _fs.collection('employee_schedule_months');

  String _monthDocId(String companyId, String employeeId, String monthStr) =>
      '${companyId}__${employeeId}__$monthStr';

  String _monthOf(String yyyyMmDd) => yyyyMmDd.substring(0, 7); // yyyy-MM

  // ─────────────────────────────────────────────
  // Guardia de transiciones de estado
  // ─────────────────────────────────────────────
  /// Aplica un cambio de estado dentro de una transacción, validando contra el
  /// estado REAL en Firestore (no el del cliente, que puede estar obsoleto).
  /// Evita transiciones inválidas y carreras entre empresa y empleado.
  Future<Result<bool>> _transition({
    required String requestId,
    required Set<TimeOffStatus> allowedFrom,
    required Map<String, dynamic> updates,
  }) async {
    try {
      await _fs.runTransaction((txn) async {
        final ref = _col().doc(requestId);
        final snap = await txn.get(ref);
        if (!snap.exists) {
          throw _TransitionError('not-found');
        }
        final current =
            TimeOffStatusX.fromCode(snap.data()?['status'] as String?);
        if (!allowedFrom.contains(current)) {
          throw _TransitionError('invalid-state');
        }
        txn.set(ref, {
          ...updates,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }).timeout(const Duration(seconds: 10));
      return Result(success: true, data: true);
    } on _TransitionError catch (e) {
      toastService.showParsedErrorCode(e.code);
      return Result(success: false, data: false, errorCode: e.code);
    } catch (e) {
      return _err(e);
    }
  }

  // ─────────────────────────────────────────────
  // Crear
  // ─────────────────────────────────────────────
  @override
  Future<Result<String>> create(TimeOffModel request) async {
    try {
      final ref = _col().doc();
      await ref.set({
        ...request.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 10));
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

  // ─────────────────────────────────────────────
  // Streams
  // ─────────────────────────────────────────────
  @override
  Stream<List<TimeOffModel>> streamByEmployee({
    required String companyId,
    required String employeeId,
  }) {
    return _col()
        .where('companyId', isEqualTo: companyId)
        .where('employeeId', isEqualTo: employeeId)
        .snapshots()
        .map(_mapAndSort);
  }

  @override
  Stream<List<TimeOffModel>> streamByCompany({
    required String companyId,
  }) {
    return _col()
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map(_mapAndSort);
  }

  List<TimeOffModel> _mapAndSort(QuerySnapshot<Map<String, dynamic>> snap) {
    final list = snap.docs
        .map((d) => TimeOffModel.fromDoc(d.id, d.data()))
        .toList();
    // Más recientes primero (createdAt puede ser null si aún no resolvió el server timestamp)
    list.sort((a, b) {
      final ad = a.createdAt;
      final bd = b.createdAt;
      if (ad == null && bd == null) return 0;
      if (ad == null) return -1; // recién creada arriba
      if (bd == null) return 1;
      return bd.compareTo(ad);
    });
    return list;
  }

  // ─────────────────────────────────────────────
  // Decisiones de la empresa
  // ─────────────────────────────────────────────
  @override
  Future<Result<bool>> companyApprove({
    required TimeOffModel request,
    required String decidedBy,
  }) async {
    return _approveAndMark(
      request: request,
      decidedBy: decidedBy,
      dates: request.effectiveDates,
      allowedFrom: {TimeOffStatus.requested, TimeOffStatus.proposed},
    );
  }

  @override
  Future<Result<bool>> companyReject({
    required TimeOffModel request,
    required String decidedBy,
    String? companyNote,
  }) async {
    // Solo se puede rechazar lo que aún está pendiente (requested o proposed).
    return _transition(
      requestId: request.id,
      allowedFrom: {TimeOffStatus.requested, TimeOffStatus.proposed},
      updates: {
        'status': TimeOffStatus.rejected.code,
        'decidedBy': decidedBy,
        if (companyNote != null) 'companyNote': companyNote,
      },
    );
  }

  @override
  Future<Result<bool>> companyPropose({
    required TimeOffModel request,
    required List<String> proposedDates,
    required String decidedBy,
    String? companyNote,
  }) async {
    // Solo se proponen fechas alternativas sobre una solicitud recién hecha.
    return _transition(
      requestId: request.id,
      allowedFrom: {TimeOffStatus.requested, TimeOffStatus.proposed},
      updates: {
        'status': TimeOffStatus.proposed.code,
        'proposedDates': proposedDates,
        'decidedBy': decidedBy,
        if (companyNote != null) 'companyNote': companyNote,
      },
    );
  }

  // ─────────────────────────────────────────────
  // Decisiones del empleado (sobre una propuesta)
  // ─────────────────────────────────────────────
  @override
  Future<Result<bool>> employeeAcceptProposal({
    required TimeOffModel request,
    required String decidedBy,
  }) async {
    // Las fechas efectivas son las propuestas por la empresa. Solo válido si
    // sigue habiendo una propuesta pendiente.
    return _approveAndMark(
      request: request,
      decidedBy: decidedBy,
      dates: request.effectiveDates,
      allowedFrom: {TimeOffStatus.proposed},
    );
  }

  @override
  Future<Result<bool>> employeeRejectProposal({
    required TimeOffModel request,
    required String decidedBy,
  }) async {
    // El empleado solo rechaza una propuesta vigente de la empresa.
    return _transition(
      requestId: request.id,
      allowedFrom: {TimeOffStatus.proposed},
      updates: {
        'status': TimeOffStatus.rejected.code,
        'decidedBy': decidedBy,
      },
    );
  }

  @override
  Future<Result<bool>> employeeCancel({
    required TimeOffModel request,
    required String decidedBy,
  }) async {
    // Solo se cancela mientras sigue pendiente (requested o proposed).
    return _transition(
      requestId: request.id,
      allowedFrom: {TimeOffStatus.requested, TimeOffStatus.proposed},
      updates: {
        'status': TimeOffStatus.cancelled.code,
        'decidedBy': decidedBy,
      },
    );
  }

  // ─────────────────────────────────────────────
  // Aprobar + marcar calendario
  // ─────────────────────────────────────────────
  /// Marca la solicitud como aprobada y escribe cada fecha como override
  /// (vacation/personal) en employee_schedule_months, agrupando por mes
  /// para minimizar escrituras. Todo en un WriteBatch atómico.
  Future<Result<bool>> _approveAndMark({
    required TimeOffModel request,
    required String decidedBy,
    required List<String> dates,
    required Set<TimeOffStatus> allowedFrom,
  }) async {
    // Agrupamos las fechas por mes y preparamos el override de cada día.
    final dayType = request.type == TimeOffType.vacation
        ? DayType.vacation
        : DayType.personal;
    final entryJson = DayEntry(type: dayType).toJson();

    final byMonth = <String, Map<String, dynamic>>{};
    for (final date in dates) {
      final month = _monthOf(date);
      byMonth.putIfAbsent(month, () => {})[date] = entryJson;
    }

    try {
      await _fs.runTransaction((txn) async {
        final reqRef = _col().doc(request.id);
        final reqSnap = await txn.get(reqRef);
        if (!reqSnap.exists) throw _TransitionError('not-found');

        final current =
            TimeOffStatusX.fromCode(reqSnap.data()?['status'] as String?);
        if (!allowedFrom.contains(current)) {
          throw _TransitionError('invalid-state');
        }

        // IMPORTANTE: en Firestore, set(merge:true) REEMPLAZA por completo los
        // mapas anidados (no hace deep-merge). Para no pisar overrides de otras
        // ausencias del mismo mes, leemos el mapa `entries` actual, fusionamos
        // en memoria y reescribimos el mapa completo. Las lecturas van ANTES de
        // cualquier escritura (requisito de las transacciones).
        final monthRefs = <String, DocumentReference<Map<String, dynamic>>>{};
        final mergedEntries = <String, Map<String, dynamic>>{};
        for (final month in byMonth.keys) {
          final ref = _monthsCol()
              .doc(_monthDocId(request.companyId, request.employeeId, month));
          monthRefs[month] = ref;
          final snap = await txn.get(ref);
          final existing = (snap.data()?['entries'] as Map?)?.map(
                (k, v) => MapEntry(k.toString(), v),
              ) ??
              <String, dynamic>{};
          mergedEntries[month] = {
            ...existing,
            ...byMonth[month]!,
          };
        }

        // 1) Estado de la solicitud → aprobada.
        txn.set(reqRef, {
          'status': TimeOffStatus.approved.code,
          'decidedBy': decidedBy,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // 2) Overrides de calendario por mes (mapa entries ya fusionado).
        for (final month in byMonth.keys) {
          txn.set(monthRefs[month]!, {
            'companyId': request.companyId,
            'employeeId': request.employeeId,
            'month': month,
            'entries': mergedEntries[month],
            'updatedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }).timeout(const Duration(seconds: 15));
      return Result(success: true, data: true);
    } on _TransitionError catch (e) {
      toastService.showParsedErrorCode(e.code);
      return Result(success: false, data: false, errorCode: e.code);
    } catch (e) {
      return _err(e);
    }
  }

  // ─────────────────────────────────────────────
  // Solapamientos
  // ─────────────────────────────────────────────
  @override
  Future<Result<List<TimeOffOverlap>>> findOverlaps({
    required String companyId,
    required String excludeEmployeeId,
    required List<String> dates,
  }) async {
    if (dates.isEmpty) return Result(success: true, data: const []);
    final wanted = dates.toSet();

    try {
      // Traemos las solicitudes de la empresa que están aprobadas o pendientes
      // (las rechazadas/canceladas no cuentan como solapamiento).
      final snap = await _col()
          .where('companyId', isEqualTo: companyId)
          .where('status', whereIn: [
            TimeOffStatus.approved.code,
            TimeOffStatus.requested.code,
            TimeOffStatus.proposed.code,
          ])
          .get()
          .timeout(const Duration(seconds: 10));

      final out = <TimeOffOverlap>[];
      for (final d in snap.docs) {
        final req = TimeOffModel.fromDoc(d.id, d.data());
        if (req.employeeId == excludeEmployeeId) continue;

        for (final date in req.effectiveDates) {
          if (wanted.contains(date)) {
            out.add(TimeOffOverlap(
              date: date,
              employeeId: req.employeeId,
              employeeName: '', // lo resuelve el controller con Brain
              type: req.type,
              status: req.status,
            ));
          }
        }
      }

      out.sort((a, b) => a.date.compareTo(b.date));
      return Result(success: true, data: out);
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

  // ─────────────────────────────────────────────
  // Helpers de error
  // ─────────────────────────────────────────────
  Result<bool> _err(Object e) {
    if (e is TimeoutException) {
      toastService.showParsedErrorCode('time-exceeded');
      return Result(success: false, data: false, errorCode: 'time-exceeded');
    }
    if (e is FirebaseException) {
      toastService.showParsedErrorCode(e.code);
      return Result(success: false, data: false, errorCode: e.code);
    }
    toastService.showParsedErrorCode('firestore-error');
    return Result(success: false, data: false, errorCode: 'firestore-error');
  }
}

/// Error de transición de estado inválida (la solicitud ya no está en un estado
/// que permita la acción solicitada).
class _TransitionError implements Exception {
  final String code;
  _TransitionError(this.code);
}
