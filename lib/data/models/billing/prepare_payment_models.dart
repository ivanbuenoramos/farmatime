class PrepareSeatChangePaymentResponse {
  final String customerId;
  final String? ephemeralKeySecret;
  final String? paymentIntentClientSecret;
  final String subscriptionId;
  final String invoiceId;
  /// true si Stripe requiere mostrar la hoja de pago (hay importe a cobrar)
  final bool requiresPayment;

  /// Importe total inmediato de la factura (en céntimos)
  final int amountCents;

  /// Moneda de la factura (ej: "eur")
  final String currency;

  /// Nueva cantidad de plazas en la suscripción tras el cambio
  final int newQuantity;

  const PrepareSeatChangePaymentResponse({
    required this.customerId,
    required this.ephemeralKeySecret,
    required this.paymentIntentClientSecret,
    required this.subscriptionId,
    required this.invoiceId,
    required this.requiresPayment,
    required this.amountCents,
    required this.currency,
    required this.newQuantity,
  });

  factory PrepareSeatChangePaymentResponse.fromJson(Map<String, dynamic> json) {
    // Compatibilidad con respuestas antiguas
    final dynamic amountRaw = json['amountCents'];
    int parsedAmount = 0;
    if (amountRaw is int) {
      parsedAmount = amountRaw;
    } else if (amountRaw != null) {
      parsedAmount = int.tryParse(amountRaw.toString()) ?? 0;
    }

    final dynamic qtyRaw = json['newQuantity'];
    int parsedQty = 0;
    if (qtyRaw is int) {
      parsedQty = qtyRaw;
    } else if (qtyRaw != null) {
      parsedQty = int.tryParse(qtyRaw.toString()) ?? 0;
    }

    return PrepareSeatChangePaymentResponse(
      customerId: (json['customerId'] ?? '').toString(),
      ephemeralKeySecret: json['ephemeralKeySecret']?.toString(),
      paymentIntentClientSecret: json['paymentIntentClientSecret']?.toString(),
      subscriptionId: (json['subscriptionId'] ?? '').toString(),
      invoiceId: (json['invoiceId'] ?? '').toString(),
      // Por compatibilidad: si el backend aún no envía requiresPayment,
      // lo inferimos a partir de si existe un clientSecret no vacío.
      requiresPayment: json['requiresPayment'] is bool
          ? (json['requiresPayment'] as bool)
          : (json['paymentIntentClientSecret'] != null &&
              json['paymentIntentClientSecret'].toString().isNotEmpty),
      amountCents: parsedAmount,
      currency: (json['currency'] ?? 'eur').toString(),
      newQuantity: parsedQty,
    );
  }

  Map<String, dynamic> toJson() => {
        'customerId': customerId,
        'ephemeralKeySecret': ephemeralKeySecret,
        'paymentIntentClientSecret': paymentIntentClientSecret,
        'subscriptionId': subscriptionId,
        'invoiceId': invoiceId,
        'requiresPayment': requiresPayment,
        'amountCents': amountCents,
        'currency': currency,
        'newQuantity': newQuantity,
      };

  PrepareSeatChangePaymentResponse copyWith({
    String? customerId,
    String? ephemeralKeySecret,
    String? paymentIntentClientSecret,
    String? subscriptionId,
    String? invoiceId,
    bool? requiresPayment,
    int? amountCents,
    String? currency,
    int? newQuantity,
  }) {
    return PrepareSeatChangePaymentResponse(
      customerId: customerId ?? this.customerId,
      ephemeralKeySecret: ephemeralKeySecret ?? this.ephemeralKeySecret,
      paymentIntentClientSecret:
          paymentIntentClientSecret ?? this.paymentIntentClientSecret,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      invoiceId: invoiceId ?? this.invoiceId,
      requiresPayment: requiresPayment ?? this.requiresPayment,
      amountCents: amountCents ?? this.amountCents,
      currency: currency ?? this.currency,
      newQuantity: newQuantity ?? this.newQuantity,
    );
  }
}