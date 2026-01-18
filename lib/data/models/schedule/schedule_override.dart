// lib/data/models/schedule/schedule_override.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'shift_segment.dart';

enum OverrideType { set, off }

class ScheduleOverride {
  final String id;
  final String companyId;
  final String employeeId;
  final String date; // 'yyyy-MM-dd' (fecha local)
  final OverrideType type;
  final List<ShiftSegment> shifts; // solo si type=set
  final String? note;

  const ScheduleOverride({
    required this.id,
    required this.companyId,
    required this.employeeId,
    required this.date,
    required this.type,
    required this.shifts,
    this.note,
  });

  Map<String, dynamic> toJson() => {
    'companyId': companyId,
    'employeeId': employeeId,
    'date': date,
    'type': type == OverrideType.set ? 'set' : 'off',
    if (type == OverrideType.set) 'shifts': shifts.map((s) => s.toJson()).toList(),
    if (note != null) 'note': note,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  factory ScheduleOverride.fromDoc(String id, Map<String, dynamic> json) => ScheduleOverride(
    id: id,
    companyId: json['companyId'] as String,
    employeeId: json['employeeId'] as String,
    date: json['date'] as String,
    type: (json['type'] as String?) == 'set' ? OverrideType.set : OverrideType.off,
    shifts: ((json['shifts'] as List?) ?? const [])
        .map((e) => ShiftSegment.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    note: json['note'] as String?,
  );
}