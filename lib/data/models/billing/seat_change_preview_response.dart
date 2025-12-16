class SeatChangePreviewResponse {
  final bool ok;
  final bool isIncrease;
  final int currentTotalSeats;
  final int newTotalSeats;

  /// prorrateo estimado “si se aplica ahora”
  final int prorationCents;
  final String currency;

  /// si es bajada, esto indica que se aplicará al final del ciclo
  final bool scheduledAtPeriodEnd;
  final DateTime? scheduledForPeriodEnd;

  const SeatChangePreviewResponse({
    required this.ok,
    required this.isIncrease,
    required this.currentTotalSeats,
    required this.newTotalSeats,
    required this.prorationCents,
    required this.currency,
    required this.scheduledAtPeriodEnd,
    required this.scheduledForPeriodEnd,
  });

  factory SeatChangePreviewResponse.fromJson(Map<String, dynamic> json) {
    DateTime? dt;
    final raw = json['scheduledForPeriodEnd'];
    if (raw is String) dt = DateTime.tryParse(raw);
    return SeatChangePreviewResponse(
      ok: json['ok'] == true,
      isIncrease: json['isIncrease'] == true,
      currentTotalSeats: (json['currentTotalSeats'] ?? 1) as int,
      newTotalSeats: (json['newTotalSeats'] ?? 1) as int,
      prorationCents: (json['prorationCents'] ?? 0) as int,
      currency: (json['currency'] ?? 'eur') as String,
      scheduledAtPeriodEnd: json['scheduledAtPeriodEnd'] == true,
      scheduledForPeriodEnd: dt,
    );
  }
}