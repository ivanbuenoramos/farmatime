// lib/data/models/schedule/shift_segment.dart
class ShiftSegment {
  final String start; // 'HHmm'
  final String end;   // 'HHmm'
  final bool endsNextDay;

  const ShiftSegment({required this.start, required this.end, this.endsNextDay = false});

  Map<String, dynamic> toJson() => {
    'start': start,
    'end': end,
    if (endsNextDay) 'endsNextDay': true,
  };

  factory ShiftSegment.fromJson(Map<String, dynamic> json) => ShiftSegment(
    start: json['start'] as String,
    end: json['end'] as String,
    endsNextDay: (json['endsNextDay'] as bool?) ?? false,
  );
}