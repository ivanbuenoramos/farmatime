import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:farmatime/data/models/schedule/schedule_day_modelo.dart';
import 'package:intl/intl.dart';

import 'package:farmatime/core/services/toast_service.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/employee_shift_model.dart';
import 'package:farmatime/data/models/schedule/day_entry.dart';
import 'package:farmatime/data/models/schedule/recurring_shift_rule.dart';
import 'package:farmatime/domain/repositories/employee_schedule_repository.dart';

class EmployeeScheduleRepositoryImpl implements EmployeeScheduleRepository {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final ToastService toastService = ToastService();

  CollectionReference<Map<String, dynamic>> _monthsCol() =>
      _fs.collection('employee_schedule_months');

  CollectionReference<Map<String, dynamic>> _rulesCol() =>
      _fs.collection('employee_schedule_rules');

  String _monthStr(int year, int month) =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

  String _monthDocId(String companyId, String employeeId, String monthStr) =>
      '${companyId}__${employeeId}__$monthStr';

  String _monthFromDateKey(String yyyyMmDd) => yyyyMmDd.substring(0, 7); // yyyy-MM

  // ─────────────────────────────────────────────
  // Overrides: MES
  // ─────────────────────────────────────────────
  @override
  Future<Result<Map<String, DayEntry>>> getMonth({
    required String companyId,
    required String employeeId,
    required int year,
    required int month,
  }) async {
    try {
      final mStr = _monthStr(year, month);
      final doc = await _monthsCol()
          .doc(_monthDocId(companyId, employeeId, mStr))
          .get()
          .timeout(const Duration(seconds: 10));

      if (!doc.exists) return Result(success: true, data: {});

      final raw = (doc.data()?['entries'] as Map<String, dynamic>? ?? {});
      final out = <String, DayEntry>{};

      raw.forEach((k, v) {
        out[k] = DayEntry.fromJson(Map<String, dynamic>.from(v as Map));
      });

      return Result(success: true, data: out);
    } on TimeoutException {
      toastService.showParsedErrorCode('time-exceeded');
      return Result(success: false, data: {}, errorCode: 'time-exceeded');
    } on FirebaseException catch (e) {
      toastService.showParsedErrorCode(e.code);
      return Result(success: false, data: {}, errorCode: e.code);
    } catch (_) {
      toastService.showParsedErrorCode('firestore-error');
      return Result(success: false, data: {}, errorCode: 'firestore-error');
    }
  }

  @override
  Future<Result<bool>> upsertMonth({
    required String companyId,
    required String employeeId,
    required int year,
    required int month,
    required Map<String, DayEntry> entries,
  }) async {
    try {
      final mStr = _monthStr(year, month);

      final payload = <String, dynamic>{};
      entries.forEach((k, v) => payload[k] = v.toJson());

      await _monthsCol()
          .doc(_monthDocId(companyId, employeeId, mStr))
          .set({
            'companyId': companyId,
            'employeeId': employeeId,
            'month': mStr,
            'entries': payload,
            'updatedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(), // merge => solo crea si no existe
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));

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

  // ─────────────────────────────────────────────
  // Overrides: CRUD por día (sin leer/escribir todo el mes)
  // ─────────────────────────────────────────────
  @override
  Future<Result<ScheduleDayModel?>> getDayOverride({
    required String companyId,
    required String employeeId,
    required String date, // yyyy-MM-dd
  }) async {
    try {
      final mStr = _monthFromDateKey(date);
      final doc = await _monthsCol()
          .doc(_monthDocId(companyId, employeeId, mStr))
          .get()
          .timeout(const Duration(seconds: 10));

      if (!doc.exists) return Result(success: true, data: null);

      final entries = (doc.data()?['entries'] as Map<String, dynamic>? ?? {});
      final raw = entries[date];
      if (raw == null) return Result(success: true, data: null);

      final entry = DayEntry.fromJson(Map<String, dynamic>.from(raw as Map));
      return Result(
        success: true,
        data: ScheduleDayModel(
          companyId: companyId,
          employeeId: employeeId,
          date: date,
          entry: entry,
        ),
      );
    } on TimeoutException {
      toastService.showParsedErrorCode('time-exceeded');
      return Result(success: false, data: null, errorCode: 'time-exceeded');
    } on FirebaseException catch (e) {
      toastService.showParsedErrorCode(e.code);
      return Result(success: false, data: null, errorCode: e.code);
    } catch (_) {
      toastService.showParsedErrorCode('firestore-error');
      return Result(success: false, data: null, errorCode: 'firestore-error');
    }
  }

  @override
  Future<Result<bool>> upsertDayOverride({
    required ScheduleDayModel day,
  }) async {
    try {
      final mStr = _monthFromDateKey(day.date);
      final docId = _monthDocId(day.companyId, day.employeeId, mStr);

      await _monthsCol().doc(docId).set({
        'companyId': day.companyId,
        'employeeId': day.employeeId,
        'month': mStr,
        'entries': { day.date: day.entry.toJson() },
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 10));

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

  @override
  Future<Result<bool>> deleteDayOverride({
    required String companyId,
    required String employeeId,
    required String date, // yyyy-MM-dd
  }) async {
    try {
      final mStr = _monthFromDateKey(date);
      final docId = _monthDocId(companyId, employeeId, mStr);

      // Borra solo la key entries.<date>
      await _monthsCol().doc(docId).set({
        'entries': { date: FieldValue.delete() },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 10));

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

  // ─────────────────────────────────────────────
  // Reglas recurrentes
  // ─────────────────────────────────────────────
  @override
  Future<Result<List<RecurringShiftRule>>> listRecurringRules({
    required String companyId,
    required String employeeId,
  }) async {
    try {
      final snap = await _rulesCol()
          .where('companyId', isEqualTo: companyId)
          .where('employeeId', isEqualTo: employeeId)
          .where('active', isEqualTo: true)
          .get()
          .timeout(const Duration(seconds: 10));

      final list = snap.docs
          .map((d) => RecurringShiftRule.fromDoc(d.id, d.data()))
          .toList()
        ..sort((a, b) => b.startsOn.compareTo(a.startsOn)); // prioridad estable

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
  Future<Result<String>> upsertRecurringRule({
    required String companyId,
    required String employeeId,
    required RecurringShiftRule rule,
  }) async {
    try {
      final ref = rule.id.isEmpty ? _rulesCol().doc() : _rulesCol().doc(rule.id);

      await ref.set({
        ...rule.toJson(),
        'companyId': companyId,
        'employeeId': employeeId,
        'updatedAt': FieldValue.serverTimestamp(),
        if (rule.id.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 10));

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
  Future<Result<bool>> deleteRecurringRule({
    required String companyId,
    required String employeeId,
    required String ruleId,
  }) async {
    try {
      // Soft delete
      await _rulesCol().doc(ruleId).set({
        'active': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 10));

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

  // ─────────────────────────────────────────────
  // Expected shifts (optimizado: overrides por mes con whereIn)
  // ─────────────────────────────────────────────
  @override
  Future<Result<Map<String, ExpectedShiftModel?>>> getExpectedShiftsForDay({
    required String companyId,
    required List<String> employeeIds,
    required DateTime dayDate,
    String? dayKey,
  }) async {
    if (employeeIds.isEmpty) return Result(success: true, data: {});

    final key = dayKey ?? DateFormat('yyyy-MM-dd').format(dayDate);
    final monthStr = DateFormat('yyyy-MM').format(dayDate);

    final out = <String, ExpectedShiftModel?>{};

    try {
      // 0) init
      for (final e in employeeIds) {
        out[e] = null;
      }

      // 1) Overrides: query por mes + whereIn (10 max)
      const int kBatch = 10;
      for (int i = 0; i < employeeIds.length; i += kBatch) {
        final slice = employeeIds.sublist(
          i,
          (i + kBatch > employeeIds.length) ? employeeIds.length : i + kBatch,
        );

        final snap = await _monthsCol()
            .where('companyId', isEqualTo: companyId)
            .where('month', isEqualTo: monthStr)
            .where('employeeId', whereIn: slice)
            .get()
            .timeout(const Duration(seconds: 10));

        for (final d in snap.docs) {
          final data = d.data();
          final empId = data['employeeId'] as String?;
          if (empId == null) continue;

          final entries = (data['entries'] as Map<String, dynamic>? ?? {});
          final raw = entries[key];
          if (raw == null) continue;

          final entry = DayEntry.fromJson(Map<String, dynamic>.from(raw as Map));
          // Solo si es work con horas
          if (entry.type == DayType.work && entry.start != null && entry.end != null) {
            out[empId] = _shiftFromDayEntry(entry, dayDate);
          } else {
            out[empId] = null;
          }
        }
      }

      // 2) Reglas: para los que siguen null, query por whereIn (10 max)
      final pending = out.entries.where((e) => e.value == null).map((e) => e.key).toList();

      for (int i = 0; i < pending.length; i += kBatch) {
        final slice = pending.sublist(
          i,
          (i + kBatch > pending.length) ? pending.length : i + kBatch,
        );

        final snap = await _rulesCol()
            .where('companyId', isEqualTo: companyId)
            .where('employeeId', whereIn: slice)
            .where('active', isEqualTo: true)
            .get()
            .timeout(const Duration(seconds: 10));

        final rulesByEmployee = <String, List<RecurringShiftRule>>{};
        for (final d in snap.docs) {
          final data = d.data();
          final empId = data['employeeId'] as String?;
          if (empId == null) continue;

          final rule = RecurringShiftRule.fromDoc(d.id, data);
          rulesByEmployee.putIfAbsent(empId, () => []).add(rule);
        }

        for (final empId in slice) {
          final rules = rulesByEmployee[empId] ?? const <RecurringShiftRule>[];
          final rule = _pickRuleForDate(rules, dayDate);
          out[empId] = _shiftFromRule(rule, dayDate);
        }
      }

      return Result(success: true, data: out);
    } on TimeoutException {
      toastService.showParsedErrorCode('time-exceeded');
      return Result(success: false, data: {}, errorCode: 'time-exceeded');
    } on FirebaseException catch (e) {
      toastService.showParsedErrorCode(e.code);
      return Result(success: false, data: {}, errorCode: e.code);
    } catch (_) {
      toastService.showParsedErrorCode('firestore-error');
      return Result(success: false, data: {}, errorCode: 'firestore-error');
    }
  }

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────
  ExpectedShiftModel _shiftFromDayEntry(DayEntry entry, DateTime dayDate) {
    final baseDay = DateTime(dayDate.year, dayDate.month, dayDate.day);

    final start = DateTime(
      baseDay.year,
      baseDay.month,
      baseDay.day,
      entry.start!.hour,
      entry.start!.minute,
    );

    var end = DateTime(
      baseDay.year,
      baseDay.month,
      baseDay.day,
      entry.end!.hour,
      entry.end!.minute,
    );

    if (end.isBefore(start)) {
      end = end.add(const Duration(days: 1));
    }

    return ExpectedShiftModel(start: start, end: end);
  }

  RecurringShiftRule? _pickRuleForDate(List<RecurringShiftRule> rules, DateTime day) {
    final d = DateTime(day.year, day.month, day.day);

    final matches = rules.where((r) {
      if (!r.active) return false;
      if (!r.weekdays.contains(d.weekday)) return false;

      final s = DateTime(r.startsOn.year, r.startsOn.month, r.startsOn.day);
      if (d.isBefore(s)) return false;

      if (r.endsOn != null) {
        final e = DateTime(r.endsOn!.year, r.endsOn!.month, r.endsOn!.day);
        if (d.isAfter(e)) return false;
      }

      return true;
    }).toList();

    if (matches.isEmpty) return null;

    // regla ganadora: más reciente (startsOn desc)
    matches.sort((a, b) => b.startsOn.compareTo(a.startsOn));
    return matches.first;
  }

  ExpectedShiftModel? _shiftFromRule(RecurringShiftRule? rule, DateTime dayDate) {
    if (rule == null) return null;

    final baseDay = DateTime(dayDate.year, dayDate.month, dayDate.day);

    final start = DateTime(
      baseDay.year,
      baseDay.month,
      baseDay.day,
      rule.startTime.hour,
      rule.startTime.minute,
    );

    var end = DateTime(
      baseDay.year,
      baseDay.month,
      baseDay.day,
      rule.endTime.hour,
      rule.endTime.minute,
    );

    if (end.isBefore(start)) {
      end = end.add(const Duration(days: 1));
    }

    return ExpectedShiftModel(start: start, end: end);
  }

  @override
  Stream<Map<String, DayEntry>> streamMonth({
    required String companyId,
    required String employeeId,
    required int year,
    required int month,
  }) {
    final mStr = _monthStr(year, month);
    final docId = _monthDocId(companyId, employeeId, mStr);

    return _monthsCol().doc(docId).snapshots().map((doc) {
      if (!doc.exists) return <String, DayEntry>{};

      final raw = (doc.data()?['entries'] as Map<String, dynamic>? ?? {});
      final out = <String, DayEntry>{};

      raw.forEach((k, v) {
        out[k] = DayEntry.fromJson(Map<String, dynamic>.from(v as Map));
      });

      return out;
    });
  }

  @override
  Stream<List<RecurringShiftRule>> streamRecurringRules({
    required String companyId,
    required String employeeId,
  }) {
    return _rulesCol()
        .where('companyId', isEqualTo: companyId)
        .where('employeeId', isEqualTo: employeeId)
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => RecurringShiftRule.fromDoc(d.id, d.data()))
              .toList()
            ..sort((a, b) => b.startsOn.compareTo(a.startsOn));
          return list;
        });
  }
}