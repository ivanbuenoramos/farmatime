import 'package:flutter/material.dart';

enum DayType { work, off, vacation }

extension DayTypeX on DayType {
  String get code => switch (this) { DayType.work => 'work', DayType.off => 'off', DayType.vacation => 'vacation' };
  static DayType fromCode(String? code) =>
      switch (code) { 'work' => DayType.work, 'vacation' => DayType.vacation, _ => DayType.off };
  String get label => switch (this) { DayType.work => 'Laboral', DayType.off => 'Libre', DayType.vacation => 'Vacaciones' };
}

class DayEntry {
  final DayType type;
  final TimeOfDay? start;
  final TimeOfDay? end;

  DayEntry({required this.type, this.start, this.end});

  static String toHHmm(TimeOfDay t) =>
      t.hour.toString().padLeft(2, '0') + t.minute.toString().padLeft(2, '0');
  static TimeOfDay fromHHmm(String hhmm) =>
      TimeOfDay(hour: int.parse(hhmm.substring(0, 2)), minute: int.parse(hhmm.substring(2, 4)));

  Map<String, dynamic> toJson() => {
        'type': type.code,
        if (start != null) 'start': toHHmm(start!),
        if (end != null) 'end': toHHmm(end!),
      };

  factory DayEntry.fromJson(Map<String, dynamic> json) => DayEntry(
        type: DayTypeX.fromCode(json['type'] as String?),
        start: json['start'] != null ? fromHHmm(json['start'] as String) : null,
        end: json['end'] != null ? fromHHmm(json['end'] as String) : null,
      );
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
String yMd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';