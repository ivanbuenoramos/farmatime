import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:farmatime/data/models/schedule/day_entry.dart';

class RecurringShiftRule {
  final String id; // doc id
  final String start; // HHmm
  final String end; // HHmm
  final List<int> weekdays; // 1..7 (Mon..Sun)
  final DateTime startsOn; // inclusive
  final DateTime? endsOn; // null => forever
  final bool active;

  const RecurringShiftRule({
    required this.id,
    required this.start,
    required this.end,
    required this.weekdays,
    required this.startsOn,
    required this.endsOn,
    required this.active,
  });

  TimeOfDay get startTime => DayEntry.fromHHmm(start);
  TimeOfDay get endTime => DayEntry.fromHHmm(end);

  bool matchesDate(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final s = DateTime(startsOn.year, startsOn.month, startsOn.day);
    final e = endsOn != null ? DateTime(endsOn!.year, endsOn!.month, endsOn!.day) : null;
    if (d.isBefore(s)) return false;
    if (e != null && d.isAfter(e)) return false;
    return active && weekdays.contains(day.weekday);
  }

  Map<String, dynamic> toJson() => {
        'start': start,
        'end': end,
        'weekdays': weekdays,
        'startsOn': Timestamp.fromDate(DateTime(startsOn.year, startsOn.month, startsOn.day)),
        if (endsOn != null) 'endsOn': Timestamp.fromDate(DateTime(endsOn!.year, endsOn!.month, endsOn!.day)),
        'active': active,
      };

  factory RecurringShiftRule.fromDoc(String id, Map<String, dynamic> json) => RecurringShiftRule(
        id: id,
        start: json['start'] as String,
        end: json['end'] as String,
        weekdays: (json['weekdays'] as List).map((e) => e as int).toList(),
        startsOn: (json['startsOn'] as Timestamp).toDate(),
        endsOn: json['endsOn'] != null ? (json['endsOn'] as Timestamp).toDate() : null,
        active: json['active'] as bool? ?? true,
      );
}