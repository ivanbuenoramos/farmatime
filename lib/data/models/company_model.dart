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

  /// (Legacy/auxiliar) plazas pagadas guardadas históricamente.
  /// Si contractedSeats está null/0, hacemos fallback a 1 + purchasedEmployeeSlots.
  final int purchasedEmployeeSlots;

  final String? stripeCustomerId;
  final String? stripeSubscriptionId;

  /// Plazas confirmadas (billadas). Incluye la gratuita.
  /// ✅ Fuente de verdad recomendada para la app.
  final int? contractedSeats;

  /// Estado de facturación (active, past_due, unpaid, none, etc.)
  final String? billingStatus;

  /// Inicio del periodo actual (según Stripe)
  final DateTime? currentPeriodStart;

  /// Fin del periodo actual (según Stripe)
  final DateTime? currentPeriodEnd;

  /// Upgrade pendiente de pago (NO se aplica hasta invoice.paid)
  final int? pendingSeats;

  /// Downgrade programado para la próxima renovación (sí limita empleados ya)
  final int? scheduledSeats;

  /// Downgrade programado (paid seats en Stripe = total-1)
  final int? scheduledPaidSeats;

  /// Para qué periodEnd aplica el downgrade (seguridad)
  final DateTime? scheduledForPeriodEnd;

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
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.pendingSeats,
    this.scheduledSeats,
    this.scheduledPaidSeats,
    this.scheduledForPeriodEnd,
    this.verifiedEmail = false,
    this.verifiedPhone = false,
    required this.createdAt,
    required this.updatedAt,
  });

  // ─────────────────────────────────────────────────────────────
  // Derivados útiles para UI / lógica
  // ─────────────────────────────────────────────────────────────

  /// Total seats disponibles (incluye la plaza gratuita)
  int get totalSeats {
    final cs = contractedSeats ?? 0;
    if (cs >= 1) return cs;

    final paid = purchasedEmployeeSlots < 0 ? 0 : purchasedEmployeeSlots;
    return 1 + paid;
  }

  /// Seats de pago (sin la gratuita)
  int get paidSeats => (totalSeats - 1).clamp(0, 999999);

  bool get hasActiveSubscription =>
      (stripeSubscriptionId ?? '').trim().isNotEmpty &&
      (billingStatus ?? 'none') != 'none';

  // ─────────────────────────────────────────────────────────────
  // Parsing helpers
  // ─────────────────────────────────────────────────────────────

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    if (v is String) {
      try {
        return DateTime.parse(v);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────
  // JSON / Firestore
  // ─────────────────────────────────────────────────────────────

  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    final purchased = (json['purchasedEmployeeSlots'] as int?) ?? 0;

    final rawContracted = json['contractedSeats'];

    int? contracted;
    if (rawContracted is num) {
      contracted = rawContracted.toInt();
    } else if (rawContracted is String) {
      contracted = int.tryParse(rawContracted);
    }

    if (contracted == null || contracted < 1) {
      contracted = 1 + (purchased < 0 ? 0 : purchased);
    }

    return CompanyModel(
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
      purchasedEmployeeSlots: purchased,
      stripeCustomerId: json['stripeCustomerId'],
      stripeSubscriptionId: json['stripeSubscriptionId'],
      contractedSeats: contracted,
      billingStatus: json['billingStatus'],
      currentPeriodStart: _parseDate(json['currentPeriodStart']),
      currentPeriodEnd: _parseDate(json['currentPeriodEnd']),
      pendingSeats: json['pendingSeats'],
      scheduledSeats: json['scheduledSeats'],
      scheduledPaidSeats: json['scheduledPaidSeats'],
      scheduledForPeriodEnd: _parseDate(json['scheduledForPeriodEnd']),
      verifiedEmail: json['verifiedEmail'] ?? false,
      verifiedPhone: json['verifiedPhone'] ?? false,
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updatedAt']) ?? DateTime.now(),
    );
  }

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
        'currentPeriodStart': currentPeriodStart?.toIso8601String(),
        'currentPeriodEnd': currentPeriodEnd?.toIso8601String(),
        'pendingSeats': pendingSeats,
        'scheduledSeats': scheduledSeats,
        'scheduledPaidSeats': scheduledPaidSeats,
        'scheduledForPeriodEnd': scheduledForPeriodEnd?.toIso8601String(),
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
        'currentPeriodStart': currentPeriodStart,
        'pendingSeats': pendingSeats,
        'scheduledSeats': scheduledSeats,
        'scheduledPaidSeats': scheduledPaidSeats,
        'scheduledForPeriodEnd': scheduledForPeriodEnd,
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
    int? pendingSeats,
    int? scheduledSeats,
    int? scheduledPaidSeats,
    DateTime? scheduledForPeriodEnd,
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
      currentPeriodStart: currentPeriodStart ?? this.currentPeriodStart,
      currentPeriodEnd: currentPeriodEnd ?? this.currentPeriodEnd,
      pendingSeats: pendingSeats ?? this.pendingSeats,
      scheduledSeats: scheduledSeats ?? this.scheduledSeats,
      scheduledPaidSeats: scheduledPaidSeats ?? this.scheduledPaidSeats,
      scheduledForPeriodEnd: scheduledForPeriodEnd ?? this.scheduledForPeriodEnd,
      verifiedEmail: verifiedEmail ?? this.verifiedEmail,
      verifiedPhone: verifiedPhone ?? this.verifiedPhone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}