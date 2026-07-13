import 'package:cloud_firestore/cloud_firestore.dart';

enum EmployeeAccountStatus {
  pending,    // pendiente de activación, todavía no ha accedido
  active,     // activo
  inactive,   // dehabilitado por impago de la empresa (no afecta al empleado), se puede recuperar
  disabled,   // deshabilitado por cancelación de suscripción (si afecta al empleado), se puede recuperar
  deleted     // cuando la empresa elimina al empleado
}
enum EmployeeRole { tecnico, auxiliar, farmaceutico, otro }
enum WorkdayType { completa, media }

class EmployeeModel {
  final String uid;
  final String email;
  final String name;
  /// True si el backend ha generado una contraseña temporal y el empleado
  /// todavía no la ha cambiado. Es un flag derivado: la contraseña en sí vive
  /// en la subcolección privada `employees/{uid}/private/credentials` (no en
  /// el doc principal, que es legible por todos los compañeros).
  final bool hasTempPassword;
  final String? photoUrl;

  /// Color base (ARGB) del avatar, tono pastel asignado al crear el empleado.
  /// Null en empleados antiguos: la UI cae al color primario.
  final int? avatarColor;
  final String companyId;
  final String? position;
  final EmployeeAccountStatus? accountStatus;
  final DateTime hireDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double hourlyRate;
  final EmployeeRole role;
  final String? roleOther;
  final WorkdayType? workdayType;
  final double vacationDaysPer30;
  final double personalDaysPerYear;

  EmployeeModel({
    required this.uid,
    required this.email,
    required this.name,
    this.hasTempPassword = false,
    this.photoUrl,
    this.avatarColor,
    required this.companyId,
    this.position,
    required this.accountStatus,
    required this.hireDate,
    required this.createdAt,
    required this.updatedAt,
    required this.hourlyRate,
    required this.role,
    this.roleOther,
    this.workdayType,
    required this.vacationDaysPer30,
    required this.personalDaysPerYear,
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    // helpers para enums seguros
    EmployeeRole roleFrom(String? v) {
      switch (v) {
        case 'tecnico': return EmployeeRole.tecnico;
        case 'auxiliar': return EmployeeRole.auxiliar;
        case 'farmaceutico': return EmployeeRole.farmaceutico;
        case 'otro': return EmployeeRole.otro;
        default: return EmployeeRole.tecnico; // default migración
      }
    }
    WorkdayType? workdayFrom(String? v) {
      switch (v) {
        case 'completa': return WorkdayType.completa;
        case 'media': return WorkdayType.media;
        default: return null;
      }
    }

    DateTime toDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    double toDouble(dynamic v, [double d = 0]) {
      if (v == null) return d;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? d;
      return d;
    }

    // hasTempPassword es el nuevo flag derivado; para docs antiguos que aún
    // tengan `tempPassword` en texto plano, derivamos el flag del propio campo.
    final bool hasTemp = json['hasTempPassword'] == true ||
        ((json['tempPassword'] as String?)?.isNotEmpty ?? false);

    return EmployeeModel(
      uid: json['uid'],
      email: json['email'],
      name: json['name'],
      hasTempPassword: hasTemp,
      photoUrl: json['photoUrl'],
      avatarColor: (json['avatarColor'] as num?)?.toInt(),
      companyId: json['companyId'],
      position: json['position'],
      accountStatus: switch (json['accountStatus'] as String?) {
        'pending' => EmployeeAccountStatus.pending,
        'active' => EmployeeAccountStatus.active,
        'inactive' => EmployeeAccountStatus.inactive,
        'disabled' => EmployeeAccountStatus.disabled,
        'deleted' => EmployeeAccountStatus.deleted,
        null => null,
        _ => EmployeeAccountStatus.active, // default migración
      },
      hireDate: toDate(json['hireDate'] ?? json['createdAt']),
      createdAt: toDate(json['createdAt']),
      updatedAt: toDate(json['updatedAt']),
      hourlyRate: toDouble(json['hourlyRate'], 0),
      role: roleFrom(json['role'] as String?),
      roleOther: json['roleOther'],
      workdayType: workdayFrom(json['workdayType'] as String?),
      vacationDaysPer30: toDouble(json['vacationDaysPer30'], 2.5),
      personalDaysPerYear: toDouble(json['personalDaysPerYear'], 0),
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'name': name,
        // NO persistimos tempPassword en el doc principal (vive en
        // employees/{uid}/private/credentials). El flag sí, como dato derivado.
        'hasTempPassword': hasTempPassword,
        'photoUrl': photoUrl,
        'avatarColor': avatarColor,
        'companyId': companyId,
        'position': position,
        'accountStatus': switch (accountStatus) {
          EmployeeAccountStatus.pending => 'pending',
          EmployeeAccountStatus.active => 'active',
          EmployeeAccountStatus.inactive => 'inactive',
          EmployeeAccountStatus.disabled => 'disabled',
          EmployeeAccountStatus.deleted => 'deleted',
          null => null,
        },
        'hireDate': hireDate.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        // nuevos
        'hourlyRate': hourlyRate,
        'role': switch (role) {
          EmployeeRole.tecnico => 'tecnico',
          EmployeeRole.auxiliar => 'auxiliar',
          EmployeeRole.farmaceutico => 'farmaceutico',
          EmployeeRole.otro => 'otro',
        },
        'roleOther': roleOther,
        'workdayType': switch (workdayType) {
          WorkdayType.completa => 'completa',
          WorkdayType.media => 'media',
          null => null,
        },
        'vacationDaysPer30': vacationDaysPer30,
        'personalDaysPerYear': personalDaysPerYear,
      }..removeWhere((k, v) => v == null);

  EmployeeModel copyWith({
    String? uid,
    String? email,
    String? name,
    bool? hasTempPassword,
    String? photoUrl,
    int? avatarColor,
    String? companyId,
    String? position,
    EmployeeAccountStatus? accountStatus,
    DateTime? hireDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? hourlyRate,
    EmployeeRole? role,
    String? roleOther,
    WorkdayType? workdayType,
    double? vacationDaysPer30,
    double? personalDaysPerYear,
  }) {
    return EmployeeModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      hasTempPassword: hasTempPassword ?? this.hasTempPassword,
      photoUrl: photoUrl ?? this.photoUrl,
      avatarColor: avatarColor ?? this.avatarColor,
      companyId: companyId ?? this.companyId,
      position: position ?? this.position,
      accountStatus: accountStatus ?? this.accountStatus,
      hireDate: hireDate ?? this.hireDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      role: role ?? this.role,
      roleOther: roleOther ?? this.roleOther,
      workdayType: workdayType ?? this.workdayType,
      vacationDaysPer30: vacationDaysPer30 ?? this.vacationDaysPer30,
      personalDaysPerYear: personalDaysPerYear ?? this.personalDaysPerYear,
    );
  }
}