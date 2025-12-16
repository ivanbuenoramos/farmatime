class SeatChangeApplyResponse {
  final bool ok;

  /// si Stripe requiere acción (SCA) devolvemos datos para PaymentSheet
  final bool requiresAction;
  final String? customerId;
  final String? ephemeralKeySecret;
  final String? paymentIntentClientSecret;

  /// info útil
  final bool appliedNow; // true en subidas (si se cobra ok) / false en bajadas (programado)
  final DateTime? effectiveDate;

  const SeatChangeApplyResponse({
    required this.ok,
    required this.requiresAction,
    required this.appliedNow,
    this.customerId,
    this.ephemeralKeySecret,
    this.paymentIntentClientSecret,
    this.effectiveDate,
  });

  factory SeatChangeApplyResponse.fromJson(Map<String, dynamic> json) {
    DateTime? dt;
    final raw = json['effectiveDate'];
    if (raw is String) dt = DateTime.tryParse(raw);

    return SeatChangeApplyResponse(
      ok: json['ok'] == true,
      requiresAction: json['requiresAction'] == true,
      appliedNow: json['appliedNow'] == true,
      customerId: json['customerId'] as String?,
      ephemeralKeySecret: json['ephemeralKeySecret'] as String?,
      paymentIntentClientSecret: json['paymentIntentClientSecret'] as String?,
      effectiveDate: dt,
    );
  }
}