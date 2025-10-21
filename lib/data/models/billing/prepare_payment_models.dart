class PrepareSeatChangePaymentResponse {
  final String customerId;
  final String ephemeralKeySecret;
  final String paymentIntentClientSecret;
  final String subscriptionId;
  final String invoiceId;
  /// true si Stripe requiere mostrar la hoja de pago (hay importe a cobrar)
  final bool requiresPayment;

  const PrepareSeatChangePaymentResponse({
    required this.customerId,
    required this.ephemeralKeySecret,
    required this.paymentIntentClientSecret,
    required this.subscriptionId,
    required this.invoiceId,
    required this.requiresPayment,
  });

  factory PrepareSeatChangePaymentResponse.fromJson(Map<String, dynamic> json) {
    return PrepareSeatChangePaymentResponse(
      customerId: (json['customerId'] ?? '').toString(),
      ephemeralKeySecret: (json['ephemeralKeySecret'] ?? '').toString(),
      paymentIntentClientSecret:
          (json['paymentIntentClientSecret'] ?? '').toString(),
      subscriptionId: (json['subscriptionId'] ?? '').toString(),
      invoiceId: (json['invoiceId'] ?? '').toString(),
      // Por compatibilidad: si el backend aún no envía requiresPayment,
      // lo inferimos a partir de si existe un clientSecret no vacío.
      requiresPayment: json['requiresPayment'] is bool
          ? (json['requiresPayment'] as bool)
          : (json['paymentIntentClientSecret'] != null &&
              (json['paymentIntentClientSecret'] as String).isNotEmpty),
    );
  }

  Map<String, dynamic> toJson() => {
        'customerId': customerId,
        'ephemeralKeySecret': ephemeralKeySecret,
        'paymentIntentClientSecret': paymentIntentClientSecret,
        'subscriptionId': subscriptionId,
        'invoiceId': invoiceId,
        'requiresPayment': requiresPayment,
      };

  PrepareSeatChangePaymentResponse copyWith({
    String? customerId,
    String? ephemeralKeySecret,
    String? paymentIntentClientSecret,
    String? subscriptionId,
    String? invoiceId,
    bool? requiresPayment,
  }) {
    return PrepareSeatChangePaymentResponse(
      customerId: customerId ?? this.customerId,
      ephemeralKeySecret: ephemeralKeySecret ?? this.ephemeralKeySecret,
      paymentIntentClientSecret:
          paymentIntentClientSecret ?? this.paymentIntentClientSecret,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      invoiceId: invoiceId ?? this.invoiceId,
      requiresPayment: requiresPayment ?? this.requiresPayment,
    );
  }
}