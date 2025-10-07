import 'package:cloud_firestore/cloud_firestore.dart';

enum BillingStatus {
  active,       // pagos al día
  trialing,     // prueba o incompleta hasta añadir método de pago
  past_due,     // pago fallido
  canceled,     // suscripción cancelada
}

BillingStatus billingStatusFromString(String? v) {
  switch (v) {
    case 'trialing': return BillingStatus.trialing;
    case 'past_due': return BillingStatus.past_due;
    case 'canceled': return BillingStatus.canceled;
    case 'active':
    default: return BillingStatus.active;
  }
}

extension BillingStatusX on BillingStatus {
  String get nameStr => toString().split('.').last;
}



class CompanyBilling {
  final String companyId;
  final String? stripeCustomerId;
  final String? stripeSubscriptionId;
  final int contractedSeats;     // cantidad contratada en Stripe (quantity)
  final int occupiedSeats;       // empleados activos (denormalizado opcional)
  final BillingStatus status;    // active/trialing/past_due/canceled
  final DateTime? currentPeriodEnd; // próxima renovación (de Stripe)
  final DateTime? updatedAt;

  const CompanyBilling({
    required this.companyId,
    this.stripeCustomerId,
    this.stripeSubscriptionId,
    required this.contractedSeats,
    required this.occupiedSeats,
    required this.status,
    this.currentPeriodEnd,
    this.updatedAt,
  });

  int get freeSeats => contractedSeats - occupiedSeats;

  factory CompanyBilling.fromJson(String id, Map<String, dynamic> json) {
    return CompanyBilling(
      companyId: id,
      stripeCustomerId: json['stripeCustomerId'] as String?,
      stripeSubscriptionId: json['stripeSubscriptionId'] as String?,
      contractedSeats: (json['contractedSeats'] as num?)?.toInt() ?? 0,
      occupiedSeats: (json['occupiedSeats'] as num?)?.toInt() ?? 0,
      status: billingStatusFromString(json['billingStatus'] as String?),
      currentPeriodEnd: (json['currentPeriodEnd'] is Timestamp)
          ? (json['currentPeriodEnd'] as Timestamp).toDate()
          : (json['currentPeriodEnd'] != null
              ? DateTime.tryParse(json['currentPeriodEnd'].toString())
              : null),
      updatedAt: (json['updatedAt'] is Timestamp)
          ? (json['updatedAt'] as Timestamp).toDate()
          : (json['updatedAt'] != null
              ? DateTime.tryParse(json['updatedAt'].toString())
              : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stripeCustomerId': stripeCustomerId,
      'stripeSubscriptionId': stripeSubscriptionId,
      'contractedSeats': contractedSeats,
      'occupiedSeats': occupiedSeats,
      'billingStatus': status.nameStr,
      'currentPeriodEnd': currentPeriodEnd != null
          ? Timestamp.fromDate(currentPeriodEnd!)
          : null,
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  CompanyBilling copyWith({
    String? stripeCustomerId,
    String? stripeSubscriptionId,
    int? contractedSeats,
    int? occupiedSeats,
    BillingStatus? status,
    DateTime? currentPeriodEnd,
    DateTime? updatedAt,
  }) {
    return CompanyBilling(
      companyId: companyId,
      stripeCustomerId: stripeCustomerId ?? this.stripeCustomerId,
      stripeSubscriptionId:
          stripeSubscriptionId ?? this.stripeSubscriptionId,
      contractedSeats: contractedSeats ?? this.contractedSeats,
      occupiedSeats: occupiedSeats ?? this.occupiedSeats,
      status: status ?? this.status,
      currentPeriodEnd: currentPeriodEnd ?? this.currentPeriodEnd,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}


class InvoiceModel {
  final String id;
  final String number;
  final int amountCents;
  final String currency;
  final String status;
  final String? pdfUrl;
  final DateTime createdAt;

  InvoiceModel({
    required this.id,
    required this.number,
    required this.amountCents,
    required this.currency,
    required this.status,
    this.pdfUrl,
    required this.createdAt,
  });

  /// 🔹 Crear desde JSON (Stripe o Firestore)
  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    final created = json['date'] ?? json['created'];
    return InvoiceModel(
      id: json['id'] ?? '',
      number: json['number'] ?? '',
      amountCents: json['amountCents'] is int
          ? json['amountCents']
          : int.tryParse('${json['amountCents'] ?? 0}') ?? 0,
      currency: (json['currency'] ?? 'eur').toUpperCase(),
      status: json['status'] ?? 'unknown',
      pdfUrl: json['pdfUrl'],
      createdAt: created is Timestamp
          ? created.toDate()
          : DateTime.fromMillisecondsSinceEpoch((created ?? 0) * 1000),
    );
  }

  /// 🔹 Convertir a JSON para almacenar en Firestore
  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'amountCents': amountCents,
        'currency': currency,
        'status': status,
        'pdfUrl': pdfUrl,
        'date': Timestamp.fromDate(createdAt),
      };

  /// 🔹 Copia modificada (immutabilidad)
  InvoiceModel copyWith({
    String? id,
    String? number,
    int? amountCents,
    String? currency,
    String? status,
    String? pdfUrl,
    DateTime? createdAt,
  }) {
    return InvoiceModel(
      id: id ?? this.id,
      number: number ?? this.number,
      amountCents: amountCents ?? this.amountCents,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 🔹 Monto formateado en euros
  String get formattedAmount =>
      '${(amountCents / 100).toStringAsFixed(2)} €';

  /// 🔹 Fecha formateada (dd/MM/yyyy)
  String get formattedDate =>
      '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';
}