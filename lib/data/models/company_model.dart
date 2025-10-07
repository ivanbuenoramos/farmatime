import 'address.dart';
import 'phone_number.dart';

class CompanyModel {
  final String id;
  final String email;
  final String? logoUrl;

  final String legalName;
  final String? vatNumber; // CIF
  final Address? address;
  final PhoneNumber? phoneNumber;

  /// Número de slots comprados localmente (deprecated, pero mantenemos compatibilidad)
  final int purchasedEmployeeSlots;

  /// Stripe mirror
  final String? stripeCustomerId;
  final String? stripeSubscriptionId;
  final int? contractedSeats; // 👈 asientos contratados en Stripe
  final String? billingStatus; // 👈 estado de la suscripción
  final DateTime? currentPeriodEnd; // 👈 fecha de renovación

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
    required this.purchasedEmployeeSlots,
    this.stripeCustomerId,
    this.stripeSubscriptionId,
    this.contractedSeats,
    this.billingStatus,
    this.currentPeriodEnd,
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
        purchasedEmployeeSlots: json['purchasedEmployeeSlots'] ?? 0,
        stripeCustomerId: json['stripeCustomerId'],
        stripeSubscriptionId: json['stripeSubscriptionId'],
        contractedSeats: json['contractedSeats'],
        billingStatus: json['billingStatus'],
        currentPeriodEnd: json['currentPeriodEnd'] != null
            ? DateTime.tryParse(json['currentPeriodEnd'].toString())
            : null,
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'logoUrl': logoUrl,
        'legalName': legalName,
        'vatNumber': vatNumber,
        'address': address?.toJson(),
        'phoneNumber': phoneNumber?.toJson(),
        'purchasedEmployeeSlots': purchasedEmployeeSlots,
        'stripeCustomerId': stripeCustomerId,
        'stripeSubscriptionId': stripeSubscriptionId,
        'contractedSeats': contractedSeats,
        'billingStatus': billingStatus,
        'currentPeriodEnd': currentPeriodEnd?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  CompanyModel copyWith({
    String? id,
    String? email,
    String? logoUrl,
    String? legalName,
    String? vatNumber,
    Address? address,
    PhoneNumber? phoneNumber,
    int? purchasedEmployeeSlots,
    String? stripeCustomerId,
    String? stripeSubscriptionId,
    int? contractedSeats,
    String? billingStatus,
    DateTime? currentPeriodEnd,
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
      purchasedEmployeeSlots: purchasedEmployeeSlots ?? this.purchasedEmployeeSlots,
      stripeCustomerId: stripeCustomerId ?? this.stripeCustomerId,
      stripeSubscriptionId: stripeSubscriptionId ?? this.stripeSubscriptionId,
      contractedSeats: contractedSeats ?? this.contractedSeats,
      billingStatus: billingStatus ?? this.billingStatus,
      currentPeriodEnd: currentPeriodEnd ?? this.currentPeriodEnd,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}