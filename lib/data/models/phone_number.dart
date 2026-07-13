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
    DateTime? lastUpdate;
    final raw = json['lastUpdate'];
    if (raw is String) {
      lastUpdate = DateTime.tryParse(raw);
    } else if (raw is DateTime) {
      lastUpdate = raw;
    }
    return PhoneNumber(
      countryCode: (json['countryCode'] as String?) ?? '',
      number: (json['number'] as String?) ?? '',
      lastUpdate: lastUpdate,
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