import 'package:cloud_firestore/cloud_firestore.dart';

class ClockInOutModel {
  final String id;
  final String employeeId;
  final String companyId;

  final DateTime clockIn;
  final DateTime? clockOut;

  final double? clockInLat;
  final double? clockInLng;

  final double? clockOutLat;
  final double? clockOutLng;

  // 🔥 NUEVOS CAMPOS DE EDICIÓN
  final bool isEdited;
  final String? editedBy; // "company" | "employee"
  final DateTime? editedAt;
  final String? editReason;
  final List<String> editedFields;

  final DateTime createdAt;
  final DateTime updatedAt;

  ClockInOutModel({
    required this.id,
    required this.employeeId,
    required this.companyId,
    required this.clockIn,
    this.clockOut,
    this.clockInLat,
    this.clockInLng,
    this.clockOutLat,
    this.clockOutLng,

    required this.isEdited,
    this.editedBy,
    this.editedAt,
    this.editReason,
    required this.editedFields,

    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'companyId': companyId,
        'clockIn': clockIn,
        'clockOut': clockOut,

        'clockInLat': clockInLat,
        'clockInLng': clockInLng,
        'clockOutLat': clockOutLat,
        'clockOutLng': clockOutLng,

        'isEdited': isEdited,
        'editedBy': editedBy,
        'editedAt': editedAt,
        'editReason': editReason,
        'editedFields': editedFields,

        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory ClockInOutModel.fromJson(Map<String, dynamic> json) {
    DateTime parse(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.parse(v.toString());
    }

    return ClockInOutModel(
      id: json['id'],
      employeeId: json['employeeId'],
      companyId: json['companyId'],
      clockIn: parse(json['clockIn']),
      clockOut: json['clockOut'] != null ? parse(json['clockOut']) : null,

      clockInLat: (json['clockInLat'] as num?)?.toDouble(),
      clockInLng: (json['clockInLng'] as num?)?.toDouble(),
      clockOutLat: (json['clockOutLat'] as num?)?.toDouble(),
      clockOutLng: (json['clockOutLng'] as num?)?.toDouble(),

      isEdited: json['isEdited'] ?? false,
      editedBy: json['editedBy'],
      editedAt: json['editedAt'] != null ? parse(json['editedAt']) : null,
      editReason: json['editReason'],
      editedFields: (json['editedFields'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),

      createdAt: parse(json['createdAt']),
      updatedAt: parse(json['updatedAt']),
    );
  }

  ClockInOutModel copyWith({
    String? id,
    String? employeeId,
    String? companyId,
    DateTime? clockIn,
    DateTime? clockOut,
    double? clockInLat,
    double? clockInLng,
    double? clockOutLat,
    double? clockOutLng,

    bool? isEdited,
    String? editedBy,
    DateTime? editedAt,
    String? editReason,
    List<String>? editedFields,

    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClockInOutModel(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      companyId: companyId ?? this.companyId,
      clockIn: clockIn ?? this.clockIn,
      clockOut: clockOut ?? this.clockOut,
      clockInLat: clockInLat ?? this.clockInLat,
      clockInLng: clockInLng ?? this.clockInLng,
      clockOutLat: clockOutLat ?? this.clockOutLat,
      clockOutLng: clockOutLng ?? this.clockOutLng,

      isEdited: isEdited ?? this.isEdited,
      editedBy: editedBy ?? this.editedBy,
      editedAt: editedAt ?? this.editedAt,
      editReason: editReason ?? this.editReason,
      editedFields: editedFields ?? this.editedFields,

      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}