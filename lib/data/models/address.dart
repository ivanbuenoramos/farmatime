class Address {

  final String address;
  final String city;
  final String state;
  final String country;
  final String zipCode;

  Address({
    required this.address,
    required this.city,
    required this.state,
    required this.country,
    required this.zipCode,
  });

  factory Address.fromJson(Map<String, dynamic> json) => Address(
        address: (json["address"] as String?) ?? '',
        city: (json["city"] as String?) ?? '',
        state: (json["province"] as String?) ?? (json["state"] as String?) ?? '',
        country: (json["country"] as String?) ?? '',
        zipCode: (json["zipCode"] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        "address": address,
        "city": city,
        "state": state,
        "country": country,
        "zipCode": zipCode,
      };

  Address copyWith({
    String? address,
    String? city,
    String? state,
    String? country,
    String? zipCode,
  }) =>
      Address(
        address: address ?? this.address,
        city: city ?? this.city,
        state: state ?? this.state,
        country: country ?? this.country,
        zipCode: zipCode ?? this.zipCode,
      );
  
  String formatAddressToString() => '$address, $city ($zipCode), $state';
  
}