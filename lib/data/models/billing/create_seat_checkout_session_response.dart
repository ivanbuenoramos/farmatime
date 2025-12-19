class CreateSeatCheckoutSessionResponse {
  final bool ok;
  final bool noPayment;
  final String? url;

  const CreateSeatCheckoutSessionResponse({
    required this.ok,
    required this.noPayment,
    this.url,
  });

  factory CreateSeatCheckoutSessionResponse.fromJson(Map<String, dynamic> json) {
    return CreateSeatCheckoutSessionResponse(
      ok: json['ok'] == true,
      noPayment: json['noPayment'] == true,
      url: json['url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'ok': ok,
        'noPayment': noPayment,
        'url': url,
      };
}