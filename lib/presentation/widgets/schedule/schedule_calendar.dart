// presentation/widgets/schedule/employee_schedule_calendar.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

// Ajusta estos imports a tus rutas reales
import 'package:farmatime/data/models/schedule/day_entry.dart';
import 'package:farmatime/data/models/schedule/recurring_shift_rule.dart';

/// Calendario de solo visualización que pinta el horario de un empleado.
/// - Colores por tipo de día (Laboral/Libre/Vacaciones)
/// - Si no hay override, calcula por reglas recurrentes
/// - Muestra la **duración total** (p.ej. "8h", "8h 30 min")
/// - Al pulsar un día, abre un diálogo con el detalle
class EmployeeScheduleCalendar extends StatelessWidget {
  const EmployeeScheduleCalendar({
    super.key,
    // Ventana del calendario
    required this.firstDay,
    required this.lastDay,
    // Estado de navegación/selección
    required this.focusedDay,
    this.selectedDay,
    this.rangeStart,
    this.rangeEnd,
    this.rangeSelectionMode = RangeSelectionMode.toggledOff,
    // Datos
    required this.overridesByDay,
    required this.rules,
    // Callbacks
    this.onDaySelected,
    this.onRangeSelected,
    this.onPageChanged,
    // Config visual
    this.locale = 'es_ES',
    this.showTimes = true,
    this.compact = true,
    this.showDayInfoOnTap = true,
  });

  final DateTime firstDay;
  final DateTime lastDay;
  final DateTime focusedDay;

  final DateTime? selectedDay;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final RangeSelectionMode rangeSelectionMode;

  /// Overrides por día (tienen prioridad sobre reglas)
  final Map<DateTime, DayEntry> overridesByDay;

  /// Reglas recurrentes semanales
  final List<RecurringShiftRule> rules;

  final void Function(DateTime selectedDay, DateTime focusedDay)? onDaySelected;
  final void Function(DateTime? start, DateTime? end, DateTime focusedDay)? onRangeSelected;
  final void Function(DateTime focusedDay)? onPageChanged;

  final String locale;
  final bool showTimes; // muestra duración
  final bool compact;
  final bool showDayInfoOnTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TableCalendar(
      locale: locale,
      firstDay: firstDay,
      lastDay: lastDay,
      focusedDay: focusedDay,
      selectedDayPredicate: (day) => isSameDay(selectedDay, day),
      rangeStartDay: rangeStart,
      rangeEndDay: rangeEnd,
      rangeSelectionMode: rangeSelectionMode,
      availableCalendarFormats: const {CalendarFormat.month: 'Mes'},
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: theme.colorScheme.primary,
          shape: BoxShape.circle,
        ),
      ),
      onDaySelected: (sel, foc) {
        if (showDayInfoOnTap) _showDayInfoDialog(context, sel);
        if (onDaySelected != null) onDaySelected!(sel, foc);
      },
      onRangeSelected: onRangeSelected,
      onPageChanged: onPageChanged,
      calendarBuilders: CalendarBuilders(
        // prioritizedBuilder aplica a TODOS los días (incl. sáb/dom que
        // defaultBuilder no cubre en table_calendar v3)
        prioritizedBuilder: (context, day, focusedDay) {
          final isOutside = day.month != focusedDay.month;
          final isToday   = isSameDay(day, DateTime.now());
          final isSelected = selectedDay != null && isSameDay(day, selectedDay);

          Color? outline;
          bool bold = false;
          if (isSelected) {
            outline = theme.colorScheme.primary;
            bold    = true;
          } else if (isToday) {
            outline = theme.colorScheme.secondary;
          }

          final cell = _dayCell(context, day, theme, outline: outline, bold: bold);
          return isOutside ? Opacity(opacity: 0.4, child: cell) : cell;
        },
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // CELDA DEL DÍA
  // ────────────────────────────────────────────────────────────────────────────

  Widget _dayCell(BuildContext context, DateTime day, ThemeData theme,
      {Color? outline, bool bold = false}) {
    final entry = _computedEntryFor(day);
    final bg = _backgroundColorFor(entry, theme, day);

    final text = Text(
      '${day.day}',
      style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500),
    );

    final dur = _workDurationOf(entry);
    final durationText = (showTimes && dur != null)
        ? Text(
            _fmtDuration(dur),
            style: Theme.of(context).textTheme.labelSmall,
            overflow: TextOverflow.ellipsis,
          )
        : const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(4),
      padding: compact ? EdgeInsets.zero : const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: outline != null ? Border.all(color: outline, width: 1.5) : null,
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          text,
          if (showTimes) durationText,
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // DIALOG DE INFORMACIÓN DEL DÍA
  // ────────────────────────────────────────────────────────────────────────────

  void _showDayInfoDialog(BuildContext context, DateTime day) {
    final theme = Theme.of(context);
    final d = _dateOnly(day);
    final rule = _firstWhereOrNull<RecurringShiftRule>(rules, (r) => r.matchesDate(d));
    final effective = _computedEntryFor(day);
    final dur = _workDurationOf(effective);

    // Estado + color + icono
    String estado = 'Libre';
    IconData icon = Icons.event_busy_rounded;

    if (effective != null) {
      switch (effective.type) {
        case DayType.work:
          estado = 'Laboral';
          icon = Icons.work_history_rounded;
          break;
        case DayType.off:
          estado = 'Libre';
          icon = Icons.event_busy_rounded;
          break;
        case DayType.vacation:
          estado = 'Vacaciones';
          icon = Icons.beach_access_rounded;
          break;
      }
    } else if (rule != null) {
      // Sin override, pero hay regla => Laboral (por regla)
      estado = 'Laboral';
      icon = Icons.schedule_rounded;
    }

    // Texto de horario
    String? rango;
    if ((effective?.type == DayType.work) && effective?.start != null && effective?.end != null) {
      rango = '${_fmtTime(effective!.start!)}–${_fmtTime(effective.end!)}';
    } else if (effective == null && rule != null) {
      rango = '${_fmtTime(rule.startTime)}–${_fmtTime(rule.endTime)}';
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_fmtFullDateEs(day)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(estado, style: TextStyle(color: theme.colorScheme.primary)),
              ],
            ),
            const SizedBox(height: 10),
            if (rango != null) ...[
              Text('Horario: $rango'),
            ],
            if (dur != null) ...[
              const SizedBox(height: 4),
              Text('Duración: ${_fmtDuration(dur)}'),
            ],
            // const SizedBox(height: 8),
            // Text('Fuente: $fuente',
            //     style: TextStyle(color: theme.colorScheme.outline)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // LÓGICA
  // ────────────────────────────────────────────────────────────────────────────

  DayEntry? _computedEntryFor(DateTime day) {
    final d = _dateOnly(day);

    // 1) override
    final override = overridesByDay[_dateOnly(d)];
    if (override != null) return override;

    // 2) regla
    final rule = _firstWhereOrNull<RecurringShiftRule>(rules, (r) => r.matchesDate(d));
    if (rule == null) return null;
    return DayEntry(type: DayType.work, start: rule.startTime, end: rule.endTime);
  }

  Color _backgroundColorFor(DayEntry? entry, ThemeData theme, DateTime day) {
    if (entry == null) {
      final hasRule = rules.any((r) => r.matchesDate(day));
      return hasRule
          ? theme.colorScheme.primary.withValues(alpha: 0.18)
          : theme.colorScheme.surfaceContainerHighest;
    }
    switch (entry.type) {
      case DayType.work:
        return theme.colorScheme.primary.withValues(alpha: 0.25);
      case DayType.off:
        return theme.colorScheme.tertiaryContainer.withValues(alpha: 0.35);
      case DayType.vacation:
        return theme.colorScheme.errorContainer.withValues(alpha: 0.45);
    }
  }

  // Duración del turno (maneja cruces de medianoche)
  Duration? _workDurationOf(DayEntry? e) {
    if (e == null) return null;
    if (e.type != DayType.work) return null;
    if (e.start == null || e.end == null) return null;
    final startM = e.start!.hour * 60 + e.start!.minute;
    final endM = e.end!.hour * 60 + e.end!.minute;
    final minutes = endM >= startM ? endM - startM : (24 * 60 - startM + endM);
    if (minutes <= 0) return null;
    return Duration(minutes: minutes);
  }

  static String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (m == 0) return '${h}h';
    return '${h}h $m min';
  }

  static String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static String _fmtFullDateEs(DateTime d) {
    // Requiere intl
    final df = DateFormat('EEEE d \'de\' MMMM y', 'es_ES');
    return df.format(d);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static T? _firstWhereOrNull<T>(Iterable<T> it, bool Function(T) test) {
    for (final e in it) {
      if (test(e)) return e;
    }
    return null;
  }
}
