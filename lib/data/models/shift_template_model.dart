import 'package:flutter/material.dart';
import 'package:farmatime/data/models/schedule/day_entry.dart';

/// Turno preestablecido que una farmacia puede reutilizar.
/// start/end se guardan como 'HHmm' para facilitar persistencia.
class ShiftTemplate {
  final String id;          // doc id ('' si aún no existe)
  final String companyId;   // farmacia propietaria
  final String name;        // p.ej. "Mañana", "Tarde", "Noche"
  final String start;       // 'HHmm'
  final String end;         // 'HHmm'
  final int? breakMinutes;  // minutos de pausa (opcional, resta del total)
  final int? color;         // ARGB opcional para UI
  final bool active;        // soft-delete o visibilidad

  const ShiftTemplate({
    required this.id,
    required this.companyId,
    required this.name,
    required this.start,
    required this.end,
    this.breakMinutes,
    this.color,
    required this.active,
  });

  /// Helpers de tiempo
  TimeOfDay get startTime => DayEntry.fromHHmm(start);
  TimeOfDay get endTime   => DayEntry.fromHHmm(end);

  /// Duración total del turno descontando pausa. Maneja cruce de medianoche.
  Duration get totalDuration {
    final startM = startTime.hour * 60 + startTime.minute;
    final endM   = endTime.hour   * 60 + endTime.minute;
    int minutes  = endM >= startM ? endM - startM : (24 * 60 - startM + endM);
    minutes -= (breakMinutes ?? 0);
    if (minutes < 0) minutes = 0;
    return Duration(minutes: minutes);
  }

  /// Texto tipo "8h" o "8h 30 min"
  String get totalDurationLabel {
    final d = totalDuration;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return m == 0 ? '${h}h' : '${h}h ${m} min';
  }

  // ----------------- JSON -----------------

  Map<String, dynamic> toJson() => {
        'companyId': companyId,
        'name': name,
        'start': start,
        'end': end,
        if (breakMinutes != null) 'breakMinutes': breakMinutes,
        if (color != null) 'color': color,
        'active': active,
      };

  factory ShiftTemplate.fromJson(Map<String, dynamic> json, {String id = ''}) {
    return ShiftTemplate(
      id: id,
      companyId: json['companyId'] as String,
      name: json['name'] as String,
      start: json['start'] as String,
      end: json['end'] as String,
      breakMinutes: json['breakMinutes'] is int ? json['breakMinutes'] as int : null,
      color: json['color'] is int ? json['color'] as int : null,
      active: (json['active'] as bool?) ?? true,
    );
  }

  factory ShiftTemplate.fromDoc(String id, Map<String, dynamic> json) =>
      ShiftTemplate.fromJson(json, id: id);

  // ----------------- Utils -----------------

  ShiftTemplate copyWith({
    String? id,
    String? companyId,
    String? name,
    String? start,
    String? end,
    int? breakMinutes,
    int? color,
    bool? active,
  }) {
    return ShiftTemplate(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      start: start ?? this.start,
      end: end ?? this.end,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      color: color ?? this.color,
      active: active ?? this.active,
    );
  }

  @override
  String toString() =>
      'ShiftTemplate(id: $id, name: $name, $start-$end, break=$breakMinutes, active=$active)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShiftTemplate &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          companyId == other.companyId &&
          name == other.name &&
          start == other.start &&
          end == other.end &&
          breakMinutes == other.breakMinutes &&
          color == other.color &&
          active == other.active;

  @override
  int get hashCode =>
      id.hashCode ^
      companyId.hashCode ^
      name.hashCode ^
      start.hashCode ^
      end.hashCode ^
      (breakMinutes ?? 0).hashCode ^
      (color ?? 0).hashCode ^
      active.hashCode;

   static ShiftTemplate empty({String companyId = ''}) => ShiftTemplate(
        id: '',
        companyId: companyId,
        name: '',
        start: '0800',
        end: '1600',
        breakMinutes: null,
        color: null,
        active: true,
      );
}