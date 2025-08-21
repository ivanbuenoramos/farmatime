// lib/data/repositories/employee_schedule_repository_impl.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/services/toast_service.dart';
import 'package:farmatime/data/models/employee_shift_model.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/employee_schedule_repository.dart';
import 'package:farmatime/data/models/schedule/day_entry.dart';
import 'package:farmatime/data/models/schedule/recurring_shift_rule.dart';
import 'package:intl/intl.dart';

class EmployeeScheduleRepositoryImpl implements EmployeeScheduleRepository {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final Brain brain = Brain();
  final ToastService toastService = ToastService();

  // ── Colecciones TOP-LEVEL
  CollectionReference<Map<String, dynamic>> _schedulesCol() =>
      _fs.collection('employee_schedules');
  CollectionReference<Map<String, dynamic>> _rulesCol() =>
      _fs.collection('employee_schedule_rules');

  // DocID único por (companyId, employeeId, year)
  String _yearDocId(String companyId, String employeeId, int year) =>
      '${companyId}__${employeeId}__$year';

  @override
  Future<Result<Map<String, DayEntry>>> getYear({
    required String companyId,
    required String employeeId,
    required int year,
  }) async {
    try {
      final id = _yearDocId(companyId, employeeId, year);
      final doc = await _schedulesCol()
          .doc(id)
          .get()
          .timeout(const Duration(seconds: 10));

      if (!doc.exists) {
        return Result(success: true, data: <String, DayEntry>{});
      }

      final data = doc.data();
      final raw = (data?['entries'] as Map<String, dynamic>? ?? {});
      final mapped = <String, DayEntry>{};
      raw.forEach((k, v) {
        mapped[k] = DayEntry.fromJson(Map<String, dynamic>.from(v as Map));
      });
      return Result(success: true, data: mapped);
    } on TimeoutException {
      toastService.showParsedErrorCode('time-exceeded');
      return Result(success: false, data: const {}, errorCode: 'time-exceeded');
    } on FirebaseException catch (e) {
      toastService.showParsedErrorCode(e.code);
      return Result(success: false, data: const {}, errorCode: e.code);
    } catch (_) {
      toastService.showParsedErrorCode('firestore-error');
      return Result(success: false, data: const {}, errorCode: 'firestore-error');
    }
  }

  @override
  Future<Result<bool>> upsertYear({
    required String companyId,
    required String employeeId,
    required int year,
    required Map<String, DayEntry> entries,
  }) async {
    try {
      final payload = <String, dynamic>{};
      entries.forEach((k, v) => payload[k] = v.toJson());

      final id = _yearDocId(companyId, employeeId, year);
      await _schedulesCol()
          .doc(id)
          .set({
            'companyId': companyId,
            'employeeId': employeeId,
            'year': year,
            'entries': payload,
            'updatedAt': FieldValue.serverTimestamp(),
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
  // Reglas recurrentes (colección independiente)
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
          // .orderBy('startsOn') // <- si quieres ordenar aquí, crea índice compuesto
          .get()
          .timeout(const Duration(seconds: 10));

      final list = snap.docs
          .map((d) => RecurringShiftRule.fromDoc(d.id, d.data()))
          .toList()
        ..sort((a, b) => a.startsOn.compareTo(b.startsOn)); // orden local

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
      final data = {
        ...rule.toJson(),
        'companyId': companyId,
        'employeeId': employeeId,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final ref = rule.id.isEmpty ? _rulesCol().doc() : _rulesCol().doc(rule.id);
      await ref.set(data, SetOptions(merge: true)).timeout(const Duration(seconds: 10));

      // Verificación (opcional)
      final check = await ref.get().timeout(const Duration(seconds: 10));
      if (!check.exists) {
        toastService.showParsedErrorCode('write-not-visible');
        return Result(success: false, data: '', errorCode: 'write-not-visible');
      }

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
      await _rulesCol().doc(ruleId).delete().timeout(const Duration(seconds: 10));
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
  Future<Result<Map<String, ExpectedShiftModel?>>> getExpectedShiftsForDay({
    required String companyId,
    required List<String> employeeIds,
    required DateTime dayDate,
    String? dayKey,
  }) async {
    if (employeeIds.isEmpty) {
      return Result(success: true, data: <String, ExpectedShiftModel?>{});
    }

    final key = dayKey ?? DateFormat('yyyy-MM-dd').format(dayDate);
    final int year = dayDate.year;

    // Resultado final
    final Map<String, ExpectedShiftModel?> out = {};

    try {
      // 1) Overrides del año (employee_schedules): 1 lectura por empleado (doc ID conocido).
      //    Para no saturar, limitamos concurrencia en lotes de 10.
      const int kBatch = 10;
      for (int i = 0; i < employeeIds.length; i += kBatch) {
        final slice = employeeIds.sublist(i, (i + kBatch > employeeIds.length) ? employeeIds.length : i + kBatch);

        final futures = slice.map((empId) async {
          try {
            final id = _yearDocId(companyId, empId, year);
            final doc = await _schedulesCol().doc(id).get().timeout(const Duration(seconds: 10));
            if (!doc.exists) {
              out[empId] = null; // de momento null, quizá reglas
              return;
            }
            final data = doc.data();
            final raw = (data?['entries'] as Map<String, dynamic>? ?? {});
            if (raw.containsKey(key)) {
              final entry = DayEntry.fromJson(Map<String, dynamic>.from(raw[key] as Map));
              out[empId] = _shiftFromDayEntry(entry, dayDate);
            } else {
              out[empId] = null;
            }
          } on TimeoutException {
            toastService.showParsedErrorCode('time-exceeded');
            out[slice.first] = null; // degradación suave
          } on FirebaseException catch (e) {
            toastService.showParsedErrorCode(e.code);
            out[slice.first] = null;
          } catch (_) {
            toastService.showParsedErrorCode('firestore-error');
            out[slice.first] = null;
          }
        }).toList();

        await Future.wait(futures);
      }

      // 2) Para los que sigan null, aplicamos reglas recurrentes
      final List<String> pending = out.entries
          .where((e) => e.value == null)
          .map((e) => e.key)
          .toList();

      // Reglas: una query por empleado (filtrada por companyId + employeeId + active)
      // También podemos limitar concurrencia
      for (int i = 0; i < pending.length; i += kBatch) {
        final slice = pending.sublist(i, (i + kBatch > pending.length) ? pending.length : i + kBatch);

        final futures = slice.map((empId) async {
          try {
            final snap = await _rulesCol()
                .where('companyId', isEqualTo: companyId)
                .where('employeeId', isEqualTo: empId)
                .where('active', isEqualTo: true)
                .get()
                .timeout(const Duration(seconds: 10));

            final rules = snap.docs
                .map((d) => RecurringShiftRule.fromDoc(d.id, d.data()))
                .toList();

            final rule = _pickRuleForDate(rules, dayDate);
            out[empId] = _shiftFromRule(rule, dayDate);
          } on TimeoutException {
            toastService.showParsedErrorCode('time-exceeded');
            out[empId] = null;
          } on FirebaseException catch (e) {
            toastService.showParsedErrorCode(e.code);
            out[empId] = null;
          } catch (_) {
            toastService.showParsedErrorCode('firestore-error');
            out[empId] = null;
          }
        }).toList();

        await Future.wait(futures);
      }

      return Result(success: true, data: out);
    } catch (_) {
      toastService.showParsedErrorCode('firestore-error');
      return Result(success: false, data: {}, errorCode: 'firestore-error');
    }
  }

  // ── Helpers privados (mismos que ya tenías, reutilizados) ──

  ExpectedShiftModel? _shiftFromDayEntry(DayEntry? e, DateTime day) {
    if (e == null) return null;
    final map = e.toJson() as Map<String, dynamic>;

    final type = (map['type'] ?? map['kind'] ?? 'work') as String;
    if (type != 'work') return null;

    final shifts = (map['shifts'] as List?) ?? (map['periods'] as List?);
    if (shifts == null || shifts.isEmpty) return null;

    final first = Map<String, dynamic>.from(shifts.first as Map);
    final s = (first['start'] ?? first['open']) as String?; // "HH:mm"
    final eStr = (first['end'] ?? first['close']) as String?;
    if (s == null || eStr == null) return null;

    return ExpectedShiftModel(start: _combine(day, s), end: _combine(day, eStr));
  }

  RecurringShiftRule? _pickRuleForDate(List<RecurringShiftRule> rules, DateTime day) {
    final wd = day.weekday; // 1..7
    for (final r in rules) {
      final m = r.toJson();
      final active = (m['active'] ?? true) == true;
      if (!active) continue;

      final startsOn = DateTime.tryParse(m['startsOn'] ?? '') ?? DateTime(2000);
      final endsOn   = DateTime.tryParse(m['endsOn'] ?? '') ?? DateTime(2100);
      final inside = !day.isBefore(DateTime(startsOn.year, startsOn.month, startsOn.day)) &&
                     !day.isAfter(DateTime(endsOn.year, endsOn.month, endsOn.day));
      if (!inside) continue;

      final rWd = (m['weekday'] as int?) ?? DateTime.monday;
      if (rWd == wd) return r;
    }
    return null;
  }

  ExpectedShiftModel? _shiftFromRule(RecurringShiftRule? r, DateTime day) {
    if (r == null) return null;
    final m = r.toJson();
    final s = (m['startTime'] ?? m['start']) as String?;
    final e = (m['endTime'] ?? m['end']) as String?;
    if (s == null || e == null) return null;
    return ExpectedShiftModel(start: _combine(day, s), end: _combine(day, e));
  }

  DateTime _combine(DateTime day, String hhmm) {
    final parts = hhmm.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    return DateTime(day.year, day.month, day.day, h, m);
  }
}
