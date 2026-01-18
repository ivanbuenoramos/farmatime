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
  
  static TimeOfDay fromHHmm(String hhmm) {
    final s = hhmm.trim();
    final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 4) {
      throw FormatException('Formato inválido para hora: "$hhmm"');
    }
    final h = int.parse(digits.substring(0, 2));
    final m = int.parse(digits.substring(2, 4));
    if (h < 0 || h > 23 || m < 0 || m > 59) {
      throw FormatException('Hora fuera de rango: "$hhmm"');
    }
    return TimeOfDay(hour: h, minute: m);
  }

  /// Acepta "HHmm", "HH:mm", "H:m", "900", etc.
  /// Devuelve null si no es parseable (evita crashes por datos malos).
  static TimeOfDay? tryParseTime(dynamic value) {
    if (value == null) return null;

    final s = value.toString().trim();
    if (s.isEmpty) return null;

    // Caso "HH:mm" o "H:m"
    if (s.contains(':')) {
      final parts = s.split(':');
      if (parts.length != 2) return null;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) return null;
      if (h < 0 || h > 23 || m < 0 || m > 59) return null;
      return TimeOfDay(hour: h, minute: m);
    }

    // Caso "HHmm" o "900" o strings con basura -> nos quedamos solo con dígitos
    final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 4) {
      final h = int.tryParse(digits.substring(0, 2));
      final m = int.tryParse(digits.substring(2, 4));
      if (h == null || m == null) return null;
      if (h < 0 || h > 23 || m < 0 || m > 59) return null;
      return TimeOfDay(hour: h, minute: m);
    }

    // Caso "900" => 9:00
    if (digits.length == 3) {
      final h = int.tryParse(digits.substring(0, 1));
      final m = int.tryParse(digits.substring(1, 3));
      if (h == null || m == null) return null;
      if (h < 0 || h > 23 || m < 0 || m > 59) return null;
      return TimeOfDay(hour: h, minute: m);
    }

    return null;
  }

  Map<String, dynamic> toJson() => {
        'type': type.code,
        if (start != null) 'start': toHHmm(start!),
        if (end != null) 'end': toHHmm(end!),
      };

  factory DayEntry.fromJson(Map<String, dynamic> json) => DayEntry(
        type: DayTypeX.fromCode(json['type'] as String?),
        start: tryParseTime(json['start']),
        end: tryParseTime(json['end']),
      );
      
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
String yMd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';