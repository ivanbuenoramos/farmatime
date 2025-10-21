class SetupCardPayload {
  final String customerId;
  final String ephemeralKeySecret;
  final String setupIntentClientSecret;
  SetupCardPayload({
    required this.customerId,
    required this.ephemeralKeySecret,
    required this.setupIntentClientSecret,
  });
}