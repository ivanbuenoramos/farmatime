class StripeIncompletePaymentModel {
  final bool hasIncomplete;
  final String? billingStatus;
  final String? customerId;
  final String? ephemeralKeySecret;
  final String? paymentIntentClientSecret;
  final int? amountCents;
  final String? currency;
  final String? invoiceId;
  final String? subscriptionId;

  const StripeIncompletePaymentModel({
    required this.hasIncomplete,
    this.billingStatus,
    this.customerId,
    this.ephemeralKeySecret,
    this.paymentIntentClientSecret,
    this.amountCents,
    this.currency,
    this.invoiceId,
    this.subscriptionId,
  });

  factory StripeIncompletePaymentModel.fromJson(Map<String, dynamic> json) {
    return StripeIncompletePaymentModel(
      hasIncomplete: json['hasIncomplete'] == true,
      billingStatus: json['billingStatus'] as String?,
      customerId: json['customerId'] as String?,
      ephemeralKeySecret: json['ephemeralKeySecret'] as String?,
      paymentIntentClientSecret:
          json['paymentIntentClientSecret'] as String?,
      amountCents: json['amountCents'] is int
          ? json['amountCents'] as int
          : (json['amountCents'] is num
              ? (json['amountCents'] as num).toInt()
              : null),
      currency: json['currency'] as String?,
      invoiceId: json['invoiceId'] as String?,
      subscriptionId: json['subscriptionId'] as String?,
    );
  }

  double get amount => (amountCents ?? 0) / 100.0;
}