class PreviewSeatChangeResponse {
  final bool noPaymentNow;
  final String currency;

  final int nowSubtotalCents;
  final int nowTaxCents;
  final int nowTotalCents;

  final int nextSubtotalCents;
  final int nextTaxCents;
  final int nextTotalCents;

  final int? currentTotalSeats;
  final int newTotalSeats;
  final String? mode;

  const PreviewSeatChangeResponse({
    required this.noPaymentNow,
    required this.currency,
    required this.nowSubtotalCents,
    required this.nowTaxCents,
    required this.nowTotalCents,
    required this.nextSubtotalCents,
    required this.nextTaxCents,
    required this.nextTotalCents,
    required this.currentTotalSeats,
    required this.newTotalSeats,
    required this.mode,
  });

  factory PreviewSeatChangeResponse.fromJson(Map<String, dynamic> json) {
    int _i(String k) => (json[k] as num?)?.toInt() ?? 0;

    return PreviewSeatChangeResponse(
      noPaymentNow: json['noPaymentNow'] == true,
      currency: (json['currency'] as String?)?.trim().isNotEmpty == true
          ? (json['currency'] as String).trim()
          : 'eur',

      nowSubtotalCents: _i('nowSubtotalCents'),
      nowTaxCents: _i('nowTaxCents'),
      nowTotalCents: _i('nowTotalCents'),

      nextSubtotalCents: _i('nextSubtotalCents'),
      nextTaxCents: _i('nextTaxCents'),
      nextTotalCents: _i('nextTotalCents'),

      currentTotalSeats: (json['currentTotalSeats'] as num?)?.toInt(),
      newTotalSeats: (json['newTotalSeats'] as num?)?.toInt() ?? 1,
      mode: json['mode'] as String?,
    );
  }
}