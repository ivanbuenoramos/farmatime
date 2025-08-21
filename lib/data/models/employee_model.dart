import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeModel {
  final String uid;
  final String email;
  final String name;
  final String? tempPassword;
  final String? photoUrl;
  final String companyId;
  final String? position;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  EmployeeModel({
    required this.uid,
    required this.email,
    required this.name,
    this.tempPassword,
    this.photoUrl,
    required this.companyId,
    this.position,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) => EmployeeModel(
        uid: json['uid'],
        email: json['email'],
        name: json['name'],
        tempPassword: json['tempPassword'],
        photoUrl: json['photoUrl'],
        companyId: json['companyId'],
        position: json['position'],
        isActive: json['isActive'],
        createdAt: json['createdAt'] is String
            ? DateTime.parse(json['createdAt'])
            : json['createdAt'] is Timestamp
                ? (json['createdAt'] as Timestamp).toDate()
                : DateTime.now(),
        updatedAt: json['updatedAt'] is String
            ? DateTime.parse(json['updatedAt'])
            : json['updatedAt'] is Timestamp
                ? (json['updatedAt'] as Timestamp).toDate()
                : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'name': name,
        'tempPassword': tempPassword,
        'photoUrl': photoUrl,
        'companyId': companyId,
        'position': position,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  
  EmployeeModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? tempPassword,
    String? photoUrl,
    String? companyId,
    String? position,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmployeeModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      tempPassword: tempPassword ?? this.tempPassword,
      photoUrl: photoUrl ?? this.photoUrl,
      companyId: companyId ?? this.companyId,
      position: position ?? this.position,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
