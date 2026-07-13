// lib/data/models/schedule/time_off_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Tipo de permiso solicitado.
enum TimeOffType { vacation, personal }

/// Estado de la solicitud.
/// Flujo:
///  - requested: el empleado la ha enviado, pendiente de la empresa.
///  - proposed:  la empresa ha propuesto fechas alternativas, pendiente del empleado.
///  - approved:  aprobada (por la empresa directa, o por el empleado tras aceptar la propuesta).
///  - rejected:  rechazada (por la empresa, o por el empleado tras rechazar la propuesta).
///  - cancelled: cancelada por el empleado antes de resolverse.
enum TimeOffStatus { requested, proposed, approved, rejected, cancelled }

extension TimeOffTypeX on TimeOffType {
  String get code => switch (this) {
        TimeOffType.vacation => 'vacation',
        TimeOffType.personal => 'personal',
      };

  String get label => switch (this) {
        TimeOffType.vacation => 'Vacaciones',
        TimeOffType.personal => 'Asuntos propios',
      };

  static TimeOffType fromCode(String? code) => switch (code) {
        'vacation' => TimeOffType.vacation,
        'personal' => TimeOffType.personal,
        _ => TimeOffType.vacation,
      };
}

extension TimeOffStatusX on TimeOffStatus {
  String get code => switch (this) {
        TimeOffStatus.requested => 'requested',
        TimeOffStatus.proposed => 'proposed',
        TimeOffStatus.approved => 'approved',
        TimeOffStatus.rejected => 'rejected',
        TimeOffStatus.cancelled => 'cancelled',
      };

  String get label => switch (this) {
        TimeOffStatus.requested => 'Pendiente',
        TimeOffStatus.proposed => 'Propuesta de fechas',
        TimeOffStatus.approved => 'Aprobada',
        TimeOffStatus.rejected => 'Rechazada',
        TimeOffStatus.cancelled => 'Cancelada',
      };

  static TimeOffStatus fromCode(String? code) => switch (code) {
        'requested' => TimeOffStatus.requested,
        'proposed' => TimeOffStatus.proposed,
        'approved' => TimeOffStatus.approved,
        'rejected' => TimeOffStatus.rejected,
        'cancelled' => TimeOffStatus.cancelled,
        _ => TimeOffStatus.requested,
      };
}

class TimeOffModel {
  final String id;
  final String companyId;
  final String employeeId;
  final TimeOffType type;
  final TimeOffStatus status;

  /// Fechas solicitadas por el empleado, formato 'yyyy-MM-dd'.
  /// Unifica rango y días sueltos: un rango se expande a la lista de días.
  final List<String> dates;

  /// Nota del empleado al solicitar.
  final String? note;

  /// Fechas propuestas por la empresa (contrapropuesta). Vacío si no hay.
  final List<String> proposedDates;

  /// Nota de la empresa al decidir (motivo de rechazo, contexto de propuesta…).
  final String? companyNote;

  /// uid de quien tomó la última decisión (empresa o empleado).
  final String? decidedBy;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TimeOffModel({
    required this.id,
    required this.companyId,
    required this.employeeId,
    required this.type,
    required this.status,
    required this.dates,
    this.note,
    this.proposedDates = const [],
    this.companyNote,
    this.decidedBy,
    this.createdAt,
    this.updatedAt,
  });

  /// Fechas efectivas: si hay propuesta de la empresa se usan esas, si no las originales.
  List<String> get effectiveDates =>
      proposedDates.isNotEmpty ? proposedDates : dates;

  bool get isPending =>
      status == TimeOffStatus.requested || status == TimeOffStatus.proposed;

  /// La empresa debe actuar (recién solicitada).
  bool get awaitingCompany => status == TimeOffStatus.requested;

  /// El empleado debe actuar (la empresa propuso fechas).
  bool get awaitingEmployee => status == TimeOffStatus.proposed;

  Map<String, dynamic> toJson() => {
        'companyId': companyId,
        'employeeId': employeeId,
        'type': type.code,
        'status': status.code,
        'dates': dates,
        if (note != null) 'note': note,
        'proposedDates': proposedDates,
        if (companyNote != null) 'companyNote': companyNote,
        if (decidedBy != null) 'decidedBy': decidedBy,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory TimeOffModel.fromDoc(String id, Map<String, dynamic> json) {
    DateTime? toDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    List<String> toStrList(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      return const [];
    }

    return TimeOffModel(
      id: id,
      companyId: json['companyId'] as String? ?? '',
      employeeId: json['employeeId'] as String? ?? '',
      type: TimeOffTypeX.fromCode(json['type'] as String?),
      status: TimeOffStatusX.fromCode(json['status'] as String?),
      dates: toStrList(json['dates']),
      note: json['note'] as String?,
      proposedDates: toStrList(json['proposedDates']),
      companyNote: json['companyNote'] as String?,
      decidedBy: json['decidedBy'] as String?,
      createdAt: toDate(json['createdAt']),
      updatedAt: toDate(json['updatedAt']),
    );
  }

  TimeOffModel copyWith({
    TimeOffType? type,
    TimeOffStatus? status,
    List<String>? dates,
    String? note,
    List<String>? proposedDates,
    String? companyNote,
    String? decidedBy,
  }) {
    return TimeOffModel(
      id: id,
      companyId: companyId,
      employeeId: employeeId,
      type: type ?? this.type,
      status: status ?? this.status,
      dates: dates ?? this.dates,
      note: note ?? this.note,
      proposedDates: proposedDates ?? this.proposedDates,
      companyNote: companyNote ?? this.companyNote,
      decidedBy: decidedBy ?? this.decidedBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
