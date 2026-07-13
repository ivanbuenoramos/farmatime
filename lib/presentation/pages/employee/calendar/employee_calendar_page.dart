// lib/presentation/pages/employee/calendar/employee_calendar_page.dart
import 'package:farmatime/data/models/schedule/day_entry.dart';
import 'package:farmatime/presentation/pages/employee/calendar/employee_calendar_controller.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart' show AvailableGestures;

import 'package:farmatime/presentation/widgets/schedule/schedule_calendar.dart';

/// Color e icono por tipo de día. Coincide con los colores de las celdas del
/// calendario para que la leyenda y el detalle sean coherentes.
({Color color, IconData icon, String label}) _styleForType(DayType t) {
  switch (t) {
    case DayType.work:
      return (
        color: const Color(0xff1971FF),
        icon: Icons.work_history_rounded,
        label: 'Jornada laboral',
      );
    case DayType.vacation:
      return (
        color: const Color(0xffE53935),
        icon: Icons.beach_access_rounded,
        label: 'Vacaciones',
      );
    case DayType.personal:
      return (
        color: const Color(0xff8E24AA),
        icon: Icons.event_note_rounded,
        label: 'Asuntos propios',
      );
    case DayType.off:
      return (
        color: const Color(0xffA5A5A5),
        icon: Icons.weekend_rounded,
        label: 'Día libre',
      );
  }
}

class EmployeeCalendarPage extends GetView<EmployeeCalendarController> {
  const EmployeeCalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi calendario'),
        titleSpacing: 16,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _showLegendModal(context),
            tooltip: 'Información de colores',
          ),
          IconButton(
            icon: const Icon(Icons.event_available_rounded),
            onPressed: controller.redirectToRequestLeave,
            tooltip: 'Solicitar vacaciones y permisos',
          ),
        ],
        bottom: _MonthSelectorBar(controller: controller),
      ),
      body: Obx(() {
        final firstLoad = controller.isLoading.value &&
            controller.overridesByDay.isEmpty &&
            controller.errorText.value == null;
        if (firstLoad) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: controller.reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _MonthSummaryCard(controller: controller),
              const SizedBox(height: 12),
              _CalendarCard(controller: controller),
              const SizedBox(height: 12),
              _DayDetailCard(controller: controller),
              if (controller.errorText.value != null) ...[
                const SizedBox(height: 12),
                _ErrorBanner(message: controller.errorText.value!),
              ],
            ],
          ),
        );
      }),
    );
  }

  void _showLegendModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _LegendSheet(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Selector de mes (parte inferior del AppBar)
// ─────────────────────────────────────────────────────────────
class _MonthSelectorBar extends StatelessWidget implements PreferredSizeWidget {
  const _MonthSelectorBar({required this.controller});
  final EmployeeCalendarController controller;

  @override
  Size get preferredSize => const Size.fromHeight(48);

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return SizedBox(
      height: 48,
      child: Obx(() {
        final label = _capitalize(
          DateFormat('MMMM y', 'es_ES').format(controller.focusedDay.value),
        );
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              color: onPrimary,
              disabledColor: onPrimary.withValues(alpha: 0.35),
              onPressed:
                  controller.canGoPrevMonth ? controller.goToPrevMonth : null,
              tooltip: 'Mes anterior',
            ),
            Text(
              label,
              style: TextStyle(
                color: onPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              color: onPrimary,
              disabledColor: onPrimary.withValues(alpha: 0.35),
              onPressed:
                  controller.canGoNextMonth ? controller.goToNextMonth : null,
              tooltip: 'Mes siguiente',
            ),
          ],
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Resumen del mes enfocado
// ─────────────────────────────────────────────────────────────
class _MonthSummaryCard extends StatelessWidget {
  const _MonthSummaryCard({required this.controller});
  final EmployeeCalendarController controller;

  static String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0 && m == 0) return '0h';
    if (m == 0) return '${h}h';
    return '${h}h ${m}min';
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      final f = controller.focusedDay.value;
      final summary = controller.monthSummary;
      final monthLabel =
          _capitalize(DateFormat('MMMM y', 'es_ES').format(f));

      return _SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_rounded,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  monthLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _SummaryMetric(
                    value: '${summary.workDays}',
                    label: 'Días de trabajo',
                    color: _styleForType(DayType.work).color,
                  ),
                ),
                _MetricDivider(),
                Expanded(
                  child: _SummaryMetric(
                    value: _fmtDuration(summary.totalWork),
                    label: 'Horas totales',
                    color: theme.colorScheme.secondary,
                  ),
                ),
                _MetricDivider(),
                Expanded(
                  child: _SummaryMetric(
                    value: '${summary.vacationDays + summary.personalDays}',
                    label: 'Ausencias',
                    color: (summary.vacationDays + summary.personalDays) > 0
                        ? _styleForType(DayType.vacation).color
                        : theme.colorScheme.tertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.value,
    required this.label,
    required this.color,
  });
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.tertiary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _MetricDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: SizedBox(
        height: 38,
        child: VerticalDivider(
          width: 1,
          thickness: 1,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Calendario
// ─────────────────────────────────────────────────────────────
class _CalendarCard extends StatelessWidget {
  const _CalendarCard({required this.controller});
  final EmployeeCalendarController controller;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Obx(
        () => EmployeeScheduleCalendar(
          firstDay: controller.firstDay.value,
          lastDay: controller.lastDay.value,
          focusedDay: controller.focusedDay.value,
          selectedDay: controller.selectedDay.value,
          overridesByDay: controller.overridesByDay,
          rules: controller.rules,
          locale: 'es_ES',
          showDayInfoOnTap: false, // el detalle se muestra en el panel inferior
          headerVisible: false, // el selector de mes vive en el AppBar
          // Sin gestos: el arrastre vertical pasa al ListView de la pantalla.
          availableGestures: AvailableGestures.none,
          onDaySelected: controller.onDaySelected,
          onPageChanged: controller.onCalendarPageChanged,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Hoja informativa de leyenda (modal)
// ─────────────────────────────────────────────────────────────
class _LegendSheet extends StatelessWidget {
  const _LegendSheet();

  static const _descriptions = {
    DayType.work: 'Tienes turno asignado ese día.',
    DayType.vacation: 'Día de vacaciones aprobado.',
    DayType.personal: 'Día de asuntos propios aprobado.',
    DayType.off: 'No tienes turno asignado.',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final types = [
      DayType.work,
      DayType.vacation,
      DayType.personal,
      DayType.off,
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette_outlined,
                    size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Colores del calendario',
                  style: theme.textTheme.headlineSmall?.copyWith(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Cada día se colorea según su estado.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.tertiary,
              ),
            ),
            const SizedBox(height: 16),
            ...types.map((t) {
              final s = _styleForType(t);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: s.color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: s.color.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Icon(s.icon, size: 18, color: s.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.label,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            _descriptions[t] ?? '',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.tertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Detalle del día seleccionado
// ─────────────────────────────────────────────────────────────
class _DayDetailCard extends StatelessWidget {
  const _DayDetailCard({required this.controller});
  final EmployeeCalendarController controller;

  static String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (m == 0) return '${h}h';
    return '${h}h ${m}min';
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      final day = controller.selectedDay.value;
      final type = controller.dayTypeFor(day);
      final style = _styleForType(type);
      final range = controller.timeRangeFor(day);
      final duration = controller.durationFor(day);
      final isToday = DateUtils.isSameDay(day, DateTime.now());

      final dateLabel =
          _capitalize(DateFormat('EEEE, d \'de\' MMMM', 'es_ES').format(day));

      return _SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: fecha + chip "Hoy"
            Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 16, color: theme.colorScheme.tertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dateLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Hoy',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Estado del día (banda de color)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: style.color.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: style.color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(style.icon, size: 20, color: style.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          style.label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: style.color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          type == DayType.work
                              ? (range ?? 'Sin horario definido')
                              : _subtitleFor(type),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.tertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Detalle del turno laboral
            if (type == DayType.work && range != null) ...[
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.schedule_rounded,
                label: 'Horario',
                value: range,
              ),
              if (duration != null) ...[
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.timelapse_rounded,
                  label: 'Duración',
                  value: _fmtDuration(duration),
                ),
              ],
            ],
          ],
        ),
      );
    });
  }

  static String _subtitleFor(DayType t) {
    switch (t) {
      case DayType.vacation:
        return 'Día de vacaciones aprobado';
      case DayType.personal:
        return 'Asuntos propios aprobado';
      case DayType.off:
        return 'No tienes turno asignado';
      case DayType.work:
        return '';
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.tertiary),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.tertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.secondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Banner de error
// ─────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              size: 18, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Tarjeta base de sección
// ─────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(14),
        child: child,
      ),
    );
  }
}
