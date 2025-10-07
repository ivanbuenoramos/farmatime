import 'package:cloud_firestore/cloud_firestore.dart';

enum SubscriptionStatus { active, trialing, pastDue, canceled }

class CompanySubscription {
  final String plan;            // "per-seat"
  final int unitAmount;         // céntimos ⇒ 1€ = 100
  final String currency;        // "EUR"
  final SubscriptionStatus status;
  final DateTime nextRenewal;
  final DateTime? updatedAt;

  const CompanySubscription({
    required this.plan,
    required this.unitAmount,
    required this.currency,
    required this.status,
    required this.nextRenewal,
    this.updatedAt,
  });

  double get unitAmountDecimal => unitAmount / 100.0;

  CompanySubscription copyWith({
    String? plan,
    int? unitAmount,
    String? currency,
    SubscriptionStatus? status,
    DateTime? nextRenewal,
    DateTime? updatedAt,
  }) {
    return CompanySubscription(
      plan: plan ?? this.plan,
      unitAmount: unitAmount ?? this.unitAmount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      nextRenewal: nextRenewal ?? this.nextRenewal,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory CompanySubscription.fromJson(Map<String, dynamic> json) {
    final statusStr = (json['status'] as String?) ?? 'active';
    return CompanySubscription(
      plan: (json['plan'] as String?) ?? 'per-seat',
      unitAmount: (json['unitAmount'] as num?)?.toInt() ?? 100,
      currency: (json['currency'] as String?) ?? 'EUR',
      status: _statusFromString(statusStr),
      nextRenewal: (json['nextRenewal'] is Timestamp)
          ? (json['nextRenewal'] as Timestamp).toDate()
          : DateTime.tryParse(json['nextRenewal']?.toString() ?? '') ??
              DateTime.now().add(const Duration(days: 30)),
      updatedAt: (json['updatedAt'] is Timestamp)
          ? (json['updatedAt'] as Timestamp).toDate()
          : (json['updatedAt'] != null
              ? DateTime.tryParse(json['updatedAt'].toString())
              : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plan': plan,
      'unitAmount': unitAmount,                 // céntimos
      'currency': currency,
      'status': status.name,
      'nextRenewal': Timestamp.fromDate(nextRenewal),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  static SubscriptionStatus _statusFromString(String v) {
    switch (v) {
      case 'trialing':
        return SubscriptionStatus.trialing;
      case 'pastDue':
        return SubscriptionStatus.pastDue;
      case 'canceled':
        return SubscriptionStatus.canceled;
      case 'active':
      default:
        return SubscriptionStatus.active;
    }
  }
}