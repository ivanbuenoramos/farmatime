class UpdateSeatsAndPayResult {
  final String? clientSecret;
  final bool free;

  const UpdateSeatsAndPayResult({
    this.clientSecret,
    this.free = false,
  });

  factory UpdateSeatsAndPayResult.fromJson(Map<String, dynamic> json) {
    return UpdateSeatsAndPayResult(
      clientSecret: json['clientSecret'],
      free: json['free'] == true,
    );
  }
}