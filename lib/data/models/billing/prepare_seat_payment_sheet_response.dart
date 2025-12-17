class PrepareSeatPaymentSheetResponse {
  final bool noPayment;

  final String? customerId;
  final String? ephemeralKey;
  final String? paymentIntentClientSecret;

  const PrepareSeatPaymentSheetResponse({
    required this.noPayment,
    this.customerId,
    this.ephemeralKey,
    this.paymentIntentClientSecret,
  });

  factory PrepareSeatPaymentSheetResponse.fromJson(Map<String, dynamic> json) {
    return PrepareSeatPaymentSheetResponse(
      noPayment: json['noPayment'] == true,
      customerId: (json['customerId'] as String?)?.trim(),
      ephemeralKey: (json['ephemeralKey'] as String?)?.trim(),
      paymentIntentClientSecret: (json['paymentIntentClientSecret'] as String?)?.trim(),
    );
  }
}