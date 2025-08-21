class PhoneNumber {

  final String countryCode;
  final String number;
  final DateTime? lastUpdate;

  PhoneNumber({
    required this.countryCode,
    required this.number,
    this.lastUpdate,
  });

  factory PhoneNumber.fromJson(Map<String, dynamic> json) {
    return PhoneNumber(
      countryCode: json['countryCode'],
      number: json['number'],
      lastUpdate: json['lastUpdate'] != null ? DateTime.parse(json['lastUpdate']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'countryCode': countryCode,
      'number': number,
      'lastUpdate': lastUpdate?.toIso8601String(),
    };
  }

  PhoneNumber copyWith({
    String? countryCode,
    String? number,
    DateTime? lastUpdate,
  }) {
    return PhoneNumber(
      countryCode: countryCode ?? this.countryCode,
      number: number ?? this.number,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }
}