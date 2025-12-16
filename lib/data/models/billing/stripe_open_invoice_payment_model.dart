class StripeOpenInvoicePaymentModel {
  final bool hasOpenInvoice;
  final bool? requiresPayment;

  final String? billingStatus;

  final String? customerId;
  final String? ephemeralKeySecret;
  final String? paymentIntentClientSecret;

  final String? invoiceId;
  final int? amountCents;
  final String? currency;

  final String? reason;

  const StripeOpenInvoicePaymentModel({
    required this.hasOpenInvoice,
    this.requiresPayment,
    this.billingStatus,
    this.customerId,
    this.ephemeralKeySecret,
    this.paymentIntentClientSecret,
    this.invoiceId,
    this.amountCents,
    this.currency,
    this.reason,
  });

  factory StripeOpenInvoicePaymentModel.fromJson(Map<String, dynamic> json) {
    return StripeOpenInvoicePaymentModel(
      hasOpenInvoice: json['hasOpenInvoice'] == true,
      requiresPayment: json['requiresPayment'] as bool?,
      billingStatus: json['billingStatus'] as String?,
      customerId: json['customerId'] as String?,
      ephemeralKeySecret: json['ephemeralKeySecret'] as String?,
      paymentIntentClientSecret: json['paymentIntentClientSecret'] as String?,
      invoiceId: json['invoiceId'] as String?,
      amountCents: (json['amountCents'] is num) ? (json['amountCents'] as num).toInt() : null,
      currency: json['currency'] as String?,
      reason: json['reason'] as String?,
    );
  }
}