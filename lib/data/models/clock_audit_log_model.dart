import 'package:cloud_firestore/cloud_firestore.dart';

/// Tipo de acción registrada en el log de auditoría de un fichaje.
///
/// El log es inmutable: cada acción genera una entrada nueva que nunca se
/// modifica ni se borra. Esto permite reconstruir el estado del fichaje en
/// cualquier momento y cumplir la normativa de registro horario (RD 8/2019),
/// que exige conservar y poder reproducir los cambios durante 4 años.
enum ClockAuditAction {
  /// Fichaje creado (estado inicial del histórico).
  created,

  /// Fichaje editado (uno o varios campos modificados).
  edited,

  /// Fichaje eliminado (reservado para uso futuro).
  deleted;

  String get value {
    switch (this) {
      case ClockAuditAction.created:
        return 'created';
      case ClockAuditAction.edited:
        return 'edited';
      case ClockAuditAction.deleted:
        return 'deleted';
    }
  }

  static ClockAuditAction fromValue(String? v) {
    switch (v) {
      case 'created':
        return ClockAuditAction.created;
      case 'deleted':
        return ClockAuditAction.deleted;
      case 'edited':
      default:
        return ClockAuditAction.edited;
    }
  }
}

/// Cambio de un único campo dentro de una entrada de auditoría: guarda el
/// valor anterior y el nuevo para poder reconstruir el fichaje.
class ClockAuditChange {
  final String field;
  final dynamic oldValue;
  final dynamic newValue;

  const ClockAuditChange({
    required this.field,
    required this.oldValue,
    required this.newValue,
  });

  /// Normaliza valores que no son nativos de Firestore (p. ej. DateTime).
  static dynamic _normalize(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return Timestamp.fromDate(v);
    return v;
  }

  static dynamic _denormalize(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    return v;
  }

  Map<String, dynamic> toJson() => {
        'field': field,
        'oldValue': _normalize(oldValue),
        'newValue': _normalize(newValue),
      };

  factory ClockAuditChange.fromJson(Map<String, dynamic> json) =>
      ClockAuditChange(
        field: json['field']?.toString() ?? '',
        oldValue: _denormalize(json['oldValue']),
        newValue: _denormalize(json['newValue']),
      );
}

/// Entrada inmutable del log de auditoría de un fichaje.
///
/// Se almacena en la subcolección `clockRecords/{entryId}/auditLog/{logId}`.
class ClockAuditLogModel {
  final String id;
  final String entryId;
  final String companyId;
  final String employeeId;

  final ClockAuditAction action;

  /// Quién realizó la acción.
  final String actorUid;

  /// Rol del actor: "company" | "employee".
  final String actorRole;

  /// Nombre legible del actor en el momento del cambio (snapshot, no se
  /// recalcula a posteriori para mantener fidelidad del histórico).
  final String? actorName;

  /// Motivo aportado por el actor (obligatorio en ediciones por normativa).
  final String? reason;

  /// Cambios campo a campo (antes/después). Vacío en una creación pura.
  final List<ClockAuditChange> changes;

  /// Momento en el que se registró la entrada.
  final DateTime at;

  const ClockAuditLogModel({
    required this.id,
    required this.entryId,
    required this.companyId,
    required this.employeeId,
    required this.action,
    required this.actorUid,
    required this.actorRole,
    this.actorName,
    this.reason,
    required this.changes,
    required this.at,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'entryId': entryId,
        'companyId': companyId,
        'employeeId': employeeId,
        'action': action.value,
        'actorUid': actorUid,
        'actorRole': actorRole,
        'actorName': actorName,
        'reason': reason,
        'changes': changes.map((c) => c.toJson()).toList(),
        'at': at,
      };

  factory ClockAuditLogModel.fromJson(Map<String, dynamic> json) {
    DateTime parse(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.parse(v.toString());
    }

    return ClockAuditLogModel(
      id: json['id']?.toString() ?? '',
      entryId: json['entryId']?.toString() ?? '',
      companyId: json['companyId']?.toString() ?? '',
      employeeId: json['employeeId']?.toString() ?? '',
      action: ClockAuditAction.fromValue(json['action']?.toString()),
      actorUid: json['actorUid']?.toString() ?? '',
      actorRole: json['actorRole']?.toString() ?? '',
      actorName: json['actorName']?.toString(),
      reason: json['reason']?.toString(),
      changes: (json['changes'] as List<dynamic>? ?? [])
          .map((e) => ClockAuditChange.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList(),
      at: parse(json['at']),
    );
  }
}
