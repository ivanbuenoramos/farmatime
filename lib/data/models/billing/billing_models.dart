import 'package:cloud_firestore/cloud_firestore.dart';

/// Estados IAP unificados para iOS y Android.
/// Mapeo:
/// - Apple: 1→active, 2→expired, 3→in_billing_retry, 4→in_grace_period, 5→revoked
/// - Google: ACTIVE→active, IN_GRACE_PERIOD→in_grace_period, ON_HOLD→on_hold,
///   PAUSED→paused, CANCELED→canceled, EXPIRED→expired, PENDING→pending
enum BillingStatus {
  active,
  inGracePeriod,
  inBillingRetry,
  onHold,
  paused,
  canceled,
  expired,
  revoked,
  pending,
  none,
}

BillingStatus billingStatusFromString(String? v) {
  switch (v) {
    case 'active': return BillingStatus.active;
    case 'in_grace_period': return BillingStatus.inGracePeriod;
    case 'in_billing_retry': return BillingStatus.inBillingRetry;
    case 'on_hold': return BillingStatus.onHold;
    case 'paused': return BillingStatus.paused;
    case 'canceled': return BillingStatus.canceled;
    case 'expired': return BillingStatus.expired;
    case 'revoked': return BillingStatus.revoked;
    case 'pending': return BillingStatus.pending;
    default: return BillingStatus.none;
  }
}

extension BillingStatusX on BillingStatus {
  /// Valor que usa el backend (snake_case).
  String get wireName {
    switch (this) {
      case BillingStatus.inGracePeriod: return 'in_grace_period';
      case BillingStatus.inBillingRetry: return 'in_billing_retry';
      case BillingStatus.onHold: return 'on_hold';
      default: return toString().split('.').last;
    }
  }

  /// Concede acceso pagado (incluye periodo de gracia y reintento de cobro).
  bool get isPaid =>
      this == BillingStatus.active ||
      this == BillingStatus.inGracePeriod ||
      this == BillingStatus.inBillingRetry;
}

class CompanyBilling {
  final String companyId;
  final String? platform; // 'ios' | 'android'
  final String? productId;
  final int contractedSeats;
  final int occupiedSeats;
  final BillingStatus status;
  final DateTime? currentPeriodEnd;
  final bool autoRenewing;
  final DateTime? updatedAt;

  const CompanyBilling({
    required this.companyId,
    this.platform,
    this.productId,
    required this.contractedSeats,
    required this.occupiedSeats,
    required this.status,
    this.currentPeriodEnd,
    this.autoRenewing = false,
    this.updatedAt,
  });

  int get freeSeats => contractedSeats - occupiedSeats;

  factory CompanyBilling.fromJson(String id, Map<String, dynamic> json) {
    final sub = (json['subscription'] as Map?)?.cast<String, dynamic>() ?? {};
    final periodEndRaw = sub['expiresAt'] ?? json['currentPeriodEnd'];

    return CompanyBilling(
      companyId: id,
      platform: sub['platform'] as String?,
      productId: sub['productId'] as String?,
      contractedSeats: (json['contractedSeats'] as num?)?.toInt() ?? 1,
      occupiedSeats: (json['occupiedSeats'] as num?)?.toInt() ?? 0,
      status: billingStatusFromString(
        (sub['status'] ?? json['billingStatus']) as String?,
      ),
      currentPeriodEnd: (periodEndRaw is Timestamp)
          ? periodEndRaw.toDate()
          : (periodEndRaw != null
              ? DateTime.tryParse(periodEndRaw.toString())
              : null),
      autoRenewing: sub['autoRenewing'] == true,
      updatedAt: (json['updatedAt'] is Timestamp)
          ? (json['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  CompanyBilling copyWith({
    int? contractedSeats,
    int? occupiedSeats,
    BillingStatus? status,
    DateTime? currentPeriodEnd,
    bool? autoRenewing,
  }) {
    return CompanyBilling(
      companyId: companyId,
      platform: platform,
      productId: productId,
      contractedSeats: contractedSeats ?? this.contractedSeats,
      occupiedSeats: occupiedSeats ?? this.occupiedSeats,
      status: status ?? this.status,
      currentPeriodEnd: currentPeriodEnd ?? this.currentPeriodEnd,
      autoRenewing: autoRenewing ?? this.autoRenewing,
      updatedAt: updatedAt,
    );
  }
}
