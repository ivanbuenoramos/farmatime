// lib/data/models/time_off/time_off_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum TimeOffType { vacation, personal, sick, unpaid, other }
enum TimeOffStatus { requested, approved, rejected, cancelled }

class TimeOffModel {
  final String id;
  final String companyId;
  final String employeeId;
  final TimeOffType type;
  final TimeOffStatus status;
  final String startDate; // 'yyyy-MM-dd'
  final String endDate;   // 'yyyy-MM-dd'
  final String? note;

  const TimeOffModel({
    required this.id,
    required this.companyId,
    required this.employeeId,
    required this.type,
    required this.status,
    required this.startDate,
    required this.endDate,
    this.note,
  });

  Map<String, dynamic> toJson() => {
    'companyId': companyId,
    'employeeId': employeeId,
    'type': type.name,
    'status': status.name,
    'startDate': startDate,
    'endDate': endDate,
    if (note != null) 'note': note,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  factory TimeOffModel.fromDoc(String id, Map<String, dynamic> json) => TimeOffModel(
    id: id,
    companyId: json['companyId'] as String,
    employeeId: json['employeeId'] as String,
    type: TimeOffType.values.firstWhere((e) => e.name == (json['type'] as String? ?? 'other'),
        orElse: () => TimeOffType.other),
    status: TimeOffStatus.values.firstWhere((e) => e.name == (json['status'] as String? ?? 'requested'),
        orElse: () => TimeOffStatus.requested),
    startDate: json['startDate'] as String,
    endDate: json['endDate'] as String,
    note: json['note'] as String?,
  );
}