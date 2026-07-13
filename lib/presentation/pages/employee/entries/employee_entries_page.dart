import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:farmatime/data/models/clock_in_out_model.dart';
import 'package:farmatime/presentation/pages/employee/entries/employee_entries_controller.dart';
import 'package:farmatime/presentation/widgets/modals/employee_day_clockings_modal.dart';

class EmployeeEntriesPage extends GetView<EmployeeEntriesController> {
  const EmployeeEntriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis fichajes'),
        titleSpacing: 16,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.hasError.value) {
          return _ErrorState(onRetry: controller.fetch);
        }

        final grouped = controller.groupedByDay;
        if (grouped.isEmpty) {
          return _EmptyState(theme: theme);
        }

        // Días más recientes primero.
        final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

        return RefreshIndicator(
          onRefresh: controller.fetch,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final day = days[i];
              final records = grouped[day]!;
              return _DayCard(
                day: day,
                records: records,
                workedMinutes: controller.workedMinutesFor(records),
                hasOpen: controller.hasOpenShift(records),
                onTap: () => showEmployeeDayClockingsModal(
                  context: context,
                  day: day,
                  records: records,
                  workedMinutes: controller.workedMinutesFor(records),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Tarjeta de un día (pulsable → abre el modal de detalle)
// ─────────────────────────────────────────────────────────────
class _DayCard extends StatelessWidget {
  final DateTime day;
  final List<ClockInOutModel> records;
  final int workedMinutes;
  final bool hasOpen;
  final VoidCallback onTap;

  const _DayCard({
    required this.day,
    required this.records,
    required this.workedMinutes,
    required this.hasOpen,
    required this.onTap,
  });

  static String _fmtDuration(int minutes) {
    if (minutes <= 0) return '0 min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}min';
    if (h > 0) return '${h}h';
    return '$m min';
  }

  String _time(DateTime d) => DateFormat('HH:mm').format(d);

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final now = DateTime.now();
    final isToday = DateUtils.isSameDay(day, now);
    final isYesterday =
        DateUtils.isSameDay(day, now.subtract(const Duration(days: 1)));

    final weekday =
        _capitalize(DateFormat('EEEE', 'es_ES').format(day));
    final dayNumber = DateFormat("d 'de' MMM", 'es_ES').format(day);

    // Primer entrada y última salida del día para la vista previa.
    final firstIn = records
        .map((r) => r.clockIn)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final lastOut = records
        .where((r) => r.clockOut != null)
        .map((r) => r.clockOut!)
        .fold<DateTime?>(null, (prev, e) {
      if (prev == null) return e;
      return e.isAfter(prev) ? e : prev;
    });

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera: fecha + badge
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            weekday,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '· $dayNumber',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.tertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isToday)
                    _Badge(label: 'Hoy', color: theme.colorScheme.primary)
                  else if (isYesterday)
                    _Badge(
                        label: 'Ayer', color: theme.colorScheme.tertiary),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  // Tiempo + turnos
                  Icon(Icons.access_time_filled_rounded,
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    _fmtDuration(workedMinutes),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '· ${records.length} ${records.length == 1 ? 'turno' : 'turnos'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded,
                      color: theme.colorScheme.tertiary),
                ],
              ),
              const SizedBox(height: 10),

              // Vista previa entrada / salida
              Row(
                children: [
                  _MiniTime(
                    icon: Icons.login_rounded,
                    color: theme.colorScheme.primary,
                    label: 'Entrada',
                    value: _time(firstIn),
                  ),
                  const SizedBox(width: 20),
                  _MiniTime(
                    icon: Icons.logout_rounded,
                    color: theme.colorScheme.error,
                    label: 'Salida',
                    value: hasOpen
                        ? 'En curso'
                        : (lastOut != null ? _time(lastOut) : '—'),
                    muted: hasOpen,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniTime extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final bool muted;

  const _MiniTime({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 15, color: muted ? theme.colorScheme.tertiary : color),
        const SizedBox(width: 5),
        Text(
          '$label ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.tertiary,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            color: muted
                ? theme.colorScheme.tertiary
                : theme.colorScheme.secondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Estados (vacío / error)
// ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final ThemeData theme;
  const _EmptyState({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_toggle_off_rounded,
                size: 56, color: theme.colorScheme.tertiary),
            const SizedBox(height: 12),
            Text(
              'Todavía no tienes fichajes',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Cuando registres entradas y salidas aparecerán aquí.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.tertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 56, color: theme.colorScheme.tertiary),
            const SizedBox(height: 12),
            Text(
              'No se pudieron cargar tus fichajes',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
