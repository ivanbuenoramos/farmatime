class ClockInOutModel {
  final String id;                  // UID del registro
  final String employeeId;           // UID del empleado
  final String companyId;            // UID de la empresa
  final DateTime clockIn;            // Hora de entrada
  final DateTime? clockOut;          // Hora de salida (puede ser null si aún no ha salido)
  final String? notes;               // Opcional: notas sobre el fichaje
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
        'clockIn': clockIn.toIso8601String(),
        'clockOut': clockOut?.toIso8601String(),
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ClockInOutModel.fromJson(Map<String, dynamic> json) {
    return ClockInOutModel(
      id: json['id'],
      employeeId: json['employeeId'],
      companyId: json['companyId'],
      clockIn: DateTime.parse(json['clockIn']),
      clockOut: json['clockOut'] != null ? DateTime.parse(json['clockOut']) : null,
      notes: json['notes'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
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
