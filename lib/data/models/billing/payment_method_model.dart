class PaymentMethodModel {
  final String id;
  final String brand;      // 'visa', 'mastercard', etc.
  final String last4;
  final int expMonth;
  final int expYear;
  final bool isDefault;

  PaymentMethodModel({
    required this.id,
    required this.brand,
    required this.last4,
    required this.expMonth,
    required this.expYear,
    required this.isDefault,
  });

  factory PaymentMethodModel.fromJson(Map<String, dynamic> json) {
    return PaymentMethodModel(
      id: json['id'] as String,
      brand: (json['brand'] ?? '').toString(),
      last4: (json['last4'] ?? '').toString(),
      expMonth: (json['expMonth'] ?? 0) as int,
      expYear: (json['expYear'] ?? 0) as int,
      isDefault: (json['isDefault'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'brand': brand,
        'last4': last4,
        'expMonth': expMonth,
        'expYear': expYear,
        'isDefault': isDefault,
      };
}