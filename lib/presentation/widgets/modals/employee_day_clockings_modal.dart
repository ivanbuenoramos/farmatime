// Modal de detalle del día para la pantalla de fichajes del empleado.
// Muestra el resumen del día y la línea de tiempo de cada turno (entrada,
// salida, duración, ediciones y ubicación si existe). No depende de mapas
// ni de la edición de la empresa: es solo lectura para el propio empleado.

import 'package:farmatime/data/models/clock_in_out_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Future<void> showEmployeeDayClockingsModal({
  required BuildContext context,
  required DateTime day,
  required List<ClockInOutModel> records,
  required int workedMinutes,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _EmployeeDaySheet(
      day: day,
      records: records,
      workedMinutes: workedMinutes,
    ),
  );
}

String _fmtDuration(int minutes) {
  if (minutes <= 0) return '0 min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h > 0 && m > 0) return '${h}h ${m}min';
  if (h > 0) return '${h}h';
  return '$m min';
}

class _EmployeeDaySheet extends StatelessWidget {
  final DateTime day;
  final List<ClockInOutModel> records;
  final int workedMinutes;

  const _EmployeeDaySheet({
    required this.day,
    required this.records,
    required this.workedMinutes,
  });

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shifts = [...records]..sort((a, b) => a.clockIn.compareTo(b.clockIn));
    final dateLabel = _capitalize(
      DateFormat("EEEE, d 'de' MMMM y", 'es_ES').format(day),
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            // Cabecera con la fecha
            Row(
              children: [
                Icon(Icons.event_rounded,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dateLabel,
                    style: theme.textTheme.headlineSmall?.copyWith(fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Resumen del día
            _DaySummary(
              workedMinutes: workedMinutes,
              shiftCount: shifts.length,
              hasOpen: shifts.any((s) => s.clockOut == null),
            ),
            const SizedBox(height: 16),

            Text(
              'Detalle de turnos',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.tertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            ...List.generate(shifts.length, (i) {
              return _ShiftCard(record: shifts[i], index: i + 1);
            }),
          ],
        );
      },
    );
  }
}

class _DaySummary extends StatelessWidget {
  final int workedMinutes;
  final int shiftCount;
  final bool hasOpen;

  const _DaySummary({
    required this.workedMinutes,
    required this.shiftCount,
    required this.hasOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryMetric(
              icon: Icons.access_time_filled_rounded,
              value: _fmtDuration(workedMinutes),
              label: 'Tiempo trabajado',
              color: theme.colorScheme.primary,
            ),
          ),
          Container(
            width: 1,
            height: 42,
            color: theme.colorScheme.outline,
          ),
          Expanded(
            child: _SummaryMetric(
              icon: Icons.repeat_rounded,
              value: '$shiftCount',
              label: shiftCount == 1 ? 'Turno' : 'Turnos',
              color: theme.colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _SummaryMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.tertiary,
          ),
        ),
      ],
    );
  }
}

class _ShiftCard extends StatelessWidget {
  final ClockInOutModel record;
  final int index;

  const _ShiftCard({required this.record, required this.index});

  String _time(DateTime d) => DateFormat('HH:mm').format(d);

  int get _minutes {
    final end = record.clockOut ?? DateTime.now();
    return end.difference(record.clockIn).inMinutes.clamp(0, 24 * 60);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOpen = record.clockOut == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Turno $index',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (isOpen)
                _Pill(
                  label: 'En curso',
                  color: theme.colorScheme.primary,
                  icon: Icons.play_circle_fill_rounded,
                )
              else
                _Pill(
                  label: _fmtDuration(_minutes),
                  color: theme.colorScheme.secondary,
                  icon: Icons.timelapse_rounded,
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Línea de tiempo entrada → salida
          _TimelineRow(
            icon: Icons.login_rounded,
            color: theme.colorScheme.primary,
            label: 'Entrada',
            time: _time(record.clockIn),
            hasCoords: record.clockInLat != null && record.clockInLng != null,
            isLast: false,
          ),
          _TimelineRow(
            icon: Icons.logout_rounded,
            color: theme.colorScheme.error,
            label: 'Salida',
            time: isOpen ? 'Sin registrar' : _time(record.clockOut!),
            hasCoords:
                record.clockOutLat != null && record.clockOutLng != null,
            isLast: true,
            muted: isOpen,
          ),

          // Sello de edición
          if (record.isEdited) ...[
            const SizedBox(height: 8),
            _EditedNote(record: record),
          ],
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String time;
  final bool hasCoords;
  final bool isLast;
  final bool muted;

  const _TimelineRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.time,
    required this.hasCoords,
    required this.isLast,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dotColor = muted ? theme.colorScheme.tertiary : color;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Eje de la línea de tiempo
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: dotColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 15, color: dotColor),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: theme.colorScheme.outline,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 12, top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.tertiary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      time,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 16,
                        color: muted
                            ? theme.colorScheme.tertiary
                            : theme.colorScheme.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (hasCoords) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 13, color: theme.colorScheme.tertiary),
                      const SizedBox(width: 3),
                      Text(
                        'Ubicación registrada',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.tertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditedNote extends StatelessWidget {
  final ClockInOutModel record;
  const _EditedNote({required this.record});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final by = record.editedBy == 'company'
        ? 'la empresa'
        : record.editedBy == 'employee'
            ? 'ti'
            : null;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.edit_note_rounded,
              size: 16, color: theme.colorScheme.tertiary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  by != null
                      ? 'Fichaje modificado por $by'
                      : 'Fichaje modificado',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (record.editReason != null &&
                    record.editReason!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    record.editReason!.trim(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.tertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _Pill({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
