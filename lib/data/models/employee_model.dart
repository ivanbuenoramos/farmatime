import 'package:cloud_firestore/cloud_firestore.dart';

enum EmployeeAccountStatus {pending, active, inactive, deleted}
enum EmployeeRole { tecnico, auxiliar, farmaceutico, otro }
enum WorkdayType { completa, media }

class EmployeeModel {
  final String uid;
  final String email;
  final String name;
  final String? tempPassword;
  final String? photoUrl;
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
    this.tempPassword,
    this.photoUrl,
    required this.companyId,
    this.position,
    required this.accountStatus,
    required this.hireDate,
    required this.createdAt,
    required this.updatedAt,
    // nuevos (con defaults razonables)
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

    return EmployeeModel(
      uid: json['uid'],
      email: json['email'],
      name: json['name'],
      tempPassword: json['tempPassword'],
      photoUrl: json['photoUrl'],
      companyId: json['companyId'],
      position: json['position'],
      accountStatus: switch (json['accountStatus'] as String?) {
        'pending' => EmployeeAccountStatus.pending,
        'active' => EmployeeAccountStatus.active,
        'inactive' => EmployeeAccountStatus.inactive,
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
        'tempPassword': tempPassword,
        'photoUrl': photoUrl,
        'companyId': companyId,
        'position': position,
        'accountStatus': switch (accountStatus) {
          EmployeeAccountStatus.pending => 'pending',
          EmployeeAccountStatus.active => 'active',
          EmployeeAccountStatus.inactive => 'inactive',
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
    String? tempPassword,
    String? photoUrl,
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
      tempPassword: tempPassword ?? this.tempPassword,
      photoUrl: photoUrl ?? this.photoUrl,
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