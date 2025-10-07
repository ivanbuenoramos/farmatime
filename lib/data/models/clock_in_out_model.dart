import 'package:cloud_firestore/cloud_firestore.dart';

class ClockInOutModel {
  final String id;                  // UID del registro
  final String employeeId;          // UID del empleado
  final String companyId;           // UID de la empresa
  final DateTime clockIn;           // Hora de entrada
  final DateTime? clockOut;         // Hora de salida (puede ser null si aún no ha salido)
  final String? notes;              // Opcional: notas sobre el fichaje
  final DateTime createdAt;
  final DateTime updatedAt;

  ClockInOutModel({
    required this.id,
    required this.employeeId,
    required this.companyId,
    required this.clockIn,
    this.clockOut,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'companyId': companyId,
        'clockIn': clockIn,               // 👈 DateTime → Firestore Timestamp
        'clockOut': clockOut,             // 👈 idem (null se guarda como null)
        'notes': notes,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory ClockInOutModel.fromJson(Map<String, dynamic> json) {
    DateTime _parse(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is Timestamp) return v.toDate();    // 👈 Firestore Timestamp
      if (v is DateTime) return v;
      return DateTime.parse(v.toString());      // 👈 String ISO (compatibilidad)
    }

    return ClockInOutModel(
      id: json['id'],
      employeeId: json['employeeId'],
      companyId: json['companyId'],
      clockIn: _parse(json['clockIn']),
      clockOut: json['clockOut'] != null ? _parse(json['clockOut']) : null,
      notes: json['notes'],
      createdAt: _parse(json['createdAt']),
      updatedAt: _parse(json['updatedAt']),
    );
  }

  ClockInOutModel copyWith({
    String? id,
    String? employeeId,
    String? companyId,
    DateTime? clockIn,
    DateTime? clockOut,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClockInOutModel(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      companyId: companyId ?? this.companyId,
      clockIn: clockIn ?? this.clockIn,
      clockOut: clockOut ?? this.clockOut,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
