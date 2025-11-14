import 'package:cloud_firestore/cloud_firestore.dart';

import 'address.dart';
import 'phone_number.dart';

enum AuthMethod {
  emailPassword,
  google,
  apple,
}

class CompanyModel {
  final String id;
  final String email;
  final String? logoUrl;

  final String legalName;
  final String? vatNumber;
  final Address? address;
  final PhoneNumber? phoneNumber;
  final AuthMethod? authMethod;

  final int purchasedEmployeeSlots;

  final String? stripeCustomerId;
  final String? stripeSubscriptionId;
  final int? contractedSeats;
  final String? billingStatus;
  final DateTime? currentPeriodEnd;

  final bool verifiedEmail;
  final bool verifiedPhone;

  final DateTime createdAt;
  final DateTime updatedAt;

  CompanyModel({
    required this.id,
    required this.email,
    this.logoUrl,
    required this.legalName,
    this.vatNumber,
    this.address,
    this.phoneNumber,
    this.authMethod = AuthMethod.emailPassword,
    required this.purchasedEmployeeSlots,
    this.stripeCustomerId,
    this.stripeSubscriptionId,
    this.contractedSeats,
    this.billingStatus,
    this.currentPeriodEnd,
    this.verifiedEmail = false,
    this.verifiedPhone = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CompanyModel.fromJson(Map<String, dynamic> json) => CompanyModel(
        id: json['id'],
        email: json['email'],
        logoUrl: json['logoUrl'],
        legalName: json['legalName'],
        vatNumber: json['vatNumber'],
        address: json['address'] != null ? Address.fromJson(json['address']) : null,
        phoneNumber: json['phoneNumber'] != null ? PhoneNumber.fromJson(json['phoneNumber']) : null,
        authMethod: json['authMethod'] != null
            ? AuthMethod.values.firstWhere(
                (e) => e.toString() == 'AuthMethod.${json['authMethod']}',
                orElse: () => AuthMethod.emailPassword,
              )
            : AuthMethod.emailPassword,
        purchasedEmployeeSlots: json['purchasedEmployeeSlots'] ?? 0,
        stripeCustomerId: json['stripeCustomerId'],
        stripeSubscriptionId: json['stripeSubscriptionId'],
        contractedSeats: json['contractedSeats'],
        billingStatus: json['billingStatus'],
        currentPeriodEnd: json['currentPeriodEnd'] is DateTime
            ? json['currentPeriodEnd']
            : json['currentPeriodEnd'] is Timestamp
                ? (json['currentPeriodEnd'] as Timestamp).toDate()
                : json['currentPeriodEnd'] is String
                    ? DateTime.parse(json['currentPeriodEnd'])
                    : null,
        verifiedEmail: json['verifiedEmail'] ?? false,
        verifiedPhone: json['verifiedPhone'] ?? false,
        createdAt: json['createdAt'] is DateTime
            ? json['createdAt']
            : json['createdAt'] is Timestamp
                ? (json['createdAt'] as Timestamp).toDate()
                : json['createdAt'] is String
                    ? DateTime.parse(json['createdAt'])
                    : DateTime.now(),
        updatedAt: json['updatedAt'] is DateTime
            ? json['updatedAt']
            : json['updatedAt'] is Timestamp
                ? (json['updatedAt'] as Timestamp).toDate()
                : json['updatedAt'] is String
                    ? DateTime.parse(json['updatedAt'])
                    : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'logoUrl': logoUrl,
        'legalName': legalName,
        'vatNumber': vatNumber,
        'address': address?.toJson(),
        'phoneNumber': phoneNumber?.toJson(),
        'authMethod': authMethod?.toString().split('.').last,
        'purchasedEmployeeSlots': purchasedEmployeeSlots,
        'stripeCustomerId': stripeCustomerId,
        'stripeSubscriptionId': stripeSubscriptionId,
        'contractedSeats': contractedSeats,
        'billingStatus': billingStatus,
        'currentPeriodEnd': currentPeriodEnd?.toIso8601String(),
        'verifiedEmail': verifiedEmail,
        'verifiedPhone': verifiedPhone,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'email': email,
        'logoUrl': logoUrl,
        'legalName': legalName,
        'vatNumber': vatNumber,
        'address': address?.toJson(),
        'phoneNumber': phoneNumber?.toJson(),
        'authMethod': authMethod?.toString().split('.').last,
        'purchasedEmployeeSlots': purchasedEmployeeSlots,
        'stripeCustomerId': stripeCustomerId,
        'stripeSubscriptionId': stripeSubscriptionId,
        'contractedSeats': contractedSeats,
        'billingStatus': billingStatus,
        'currentPeriodEnd': currentPeriodEnd,
        'verifiedEmail': verifiedEmail,
        'verifiedPhone': verifiedPhone,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  CompanyModel copyWith({
    String? id,
    String? email,
    String? logoUrl,
    String? legalName,
    String? vatNumber,
    Address? address,
    PhoneNumber? phoneNumber,
    AuthMethod? authMethod,
    int? purchasedEmployeeSlots,
    String? stripeCustomerId,
    String? stripeSubscriptionId,
    int? contractedSeats,
    String? billingStatus,
    DateTime? currentPeriodEnd,
    bool? verifiedEmail,
    bool? verifiedPhone,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CompanyModel(
      id: id ?? this.id,
      email: email ?? this.email,
      logoUrl: logoUrl ?? this.logoUrl,
      legalName: legalName ?? this.legalName,
      vatNumber: vatNumber ?? this.vatNumber,
      address: address ?? this.address,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      authMethod: authMethod ?? this.authMethod,
      purchasedEmployeeSlots: purchasedEmployeeSlots ?? this.purchasedEmployeeSlots,
      stripeCustomerId: stripeCustomerId ?? this.stripeCustomerId,
      stripeSubscriptionId: stripeSubscriptionId ?? this.stripeSubscriptionId,
      contractedSeats: contractedSeats ?? this.contractedSeats,
      billingStatus: billingStatus ?? this.billingStatus,
      currentPeriodEnd: currentPeriodEnd ?? this.currentPeriodEnd,
      verifiedEmail: verifiedEmail ?? this.verifiedEmail,
      verifiedPhone: verifiedPhone ?? this.verifiedPhone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}