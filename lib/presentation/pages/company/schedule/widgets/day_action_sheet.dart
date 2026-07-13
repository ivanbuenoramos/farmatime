import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:farmatime/data/models/schedule/day_entry.dart';
import 'package:farmatime/presentation/pages/company/schedule/company_employee_schedule_controller.dart';
import 'package:farmatime/presentation/pages/company/schedule/widgets/pick_shift_bottom_sheet.dart';

/// Hoja inferior que se abre al tocar un día (o rango) en el calendario.
/// Muestra el estado actual del día y ofrece las acciones de asignación
/// de forma clara: turno laboral, libre, vacaciones o quitar la asignación.
class DayActionSheet extends StatelessWidget {
  const DayActionSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const DayActionSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: GetBuilder<EmployeeScheduleController>(
        builder: (c) {
          final dates = c.selectedDates;
          if (dates.isEmpty) {
            // No debería ocurrir, pero evitamos pantallas vacías.
            return const SizedBox(height: 1);
          }

          final isRange = dates.length > 1;
          final firstDay = dates.first;
          final entry = isRange ? null : c.computedEntryFor(firstDay);
          final source = isRange ? null : c.sourceFor(firstDay);

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              // Manija de la hoja
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Header(dates: dates),
                    const SizedBox(height: 14),
                    if (!isRange)
                      _CurrentStateChip(entry: entry, source: source!, controller: c)
                    else
                      _RangeSummary(count: dates.length),
                    const SizedBox(height: 16),
                    _LeaveBalances(controller: c),
                    const SizedBox(height: 20),
                    Text(
                      'Asignar a ${isRange ? 'estos días' : 'este día'}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    _ActionButton(
                      icon: Icons.work_history_rounded,
                      label: 'Turno laboral',
                      color: theme.colorScheme.primary,
                      onTap: () => _assignWork(context, c),
                    ),
                    const SizedBox(height: 10),
                    _ActionButton(
                      icon: Icons.free_breakfast_rounded,
                      label: 'Día libre',
                      color: const Color(0xff37A852),
                      onTap: () async {
                        await c.setForSelection(DayEntry(type: DayType.off));
                        if (context.mounted) _closeAndConfirm(context);
                      },
                    ),
                    const SizedBox(height: 10),
                    _ActionButton(
                      icon: Icons.beach_access_rounded,
                      label: 'Vacaciones',
                      color: theme.colorScheme.error,
                      onTap: () => _assignLeave(context, c, DayType.vacation),
                    ),
                    const SizedBox(height: 10),
                    _ActionButton(
                      icon: Icons.event_available_rounded,
                      label: 'Asuntos propios',
                      color: const Color(0xff8B5CF6),
                      onTap: () => _assignLeave(context, c, DayType.personal),
                    ),
                    // "Quitar" solo tiene sentido si hay un override editado.
                    if (isRange || source == DayEntrySource.override) ...[
                      const SizedBox(height: 10),
                      _ActionButton(
                        icon: Icons.restart_alt_rounded,
                        label: 'Quitar asignación',
                        color: theme.colorScheme.tertiary,
                        outlined: true,
                        onTap: () async {
                          await c.clearSelection();
                          if (context.mounted) _closeAndConfirm(context);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _closeAndConfirm(BuildContext context) {
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  /// Asigna vacaciones / asuntos propios a la selección, validando el saldo
  /// disponible del empleado. Si la asignación supera el saldo, pide
  /// confirmación explícita antes de aplicarla.
  Future<void> _assignLeave(
    BuildContext context,
    EmployeeScheduleController c,
    DayType type,
  ) async {
    final isVacation = type == DayType.vacation;
    final label = isVacation ? 'vacaciones' : 'asuntos propios';

    Future<void> apply() async {
      await c.setForSelection(DayEntry(type: type));
      if (context.mounted) _closeAndConfirm(context);
    }

    // Si no tenemos saldos cargados, no bloqueamos (se asigna directamente).
    if (!c.balancesReady.value || !c.exceedsBalance(type)) {
      await apply();
      return;
    }

    // Supera el saldo → pedir confirmación.
    final available = c.availableFor(type);
    final newDays = c.newDaysForType(type);
    final overflow = c.overflowFor(type);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          icon: Icon(Icons.warning_amber_rounded,
              color: theme.colorScheme.error, size: 32),
          title: Text('Sin $label suficientes'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A ${c.employeeName} le quedan '
                '${_fmtDays(available)} de $label disponibles este año, '
                'y estás asignando $newDays día${newDays == 1 ? '' : 's'}.',
              ),
              const SizedBox(height: 8),
              Text(
                'Se excede en $overflow día${overflow == 1 ? '' : 's'}.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                '¿Quieres asignar ${isVacation ? 'las vacaciones' : 'los asuntos propios'} de todas formas?',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Asignar igualmente'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await apply();
    }
  }

  static String _fmtDays(double v) {
    // Muestra entero si no tiene decimales relevantes, si no 1 decimal.
    final rounded = (v * 10).round() / 10;
    if (rounded == rounded.roundToDouble()) {
      return '${rounded.round()} día${rounded.round() == 1 ? '' : 's'}';
    }
    return '$rounded días';
  }

  Future<void> _assignWork(
      BuildContext context, EmployeeScheduleController c) async {
    // Sin plantillas: pedimos horas manualmente.
    if (c.shiftTemplates.isEmpty) {
      final from = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 8, minute: 0),
        helpText: 'Hora de inicio',
      );
      if (from == null || !context.mounted) return;
      final to = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 16, minute: 0),
        helpText: 'Hora de fin',
      );
      if (to == null) return;
      await c.setForSelection(DayEntry(type: DayType.work, start: from, end: to));
      if (context.mounted) _closeAndConfirm(context);
      return;
    }

    // Con plantillas: hoja de selección de turno.
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => PickShiftBottomSheet(
        templates: c.shiftTemplates,
        onApply: (start, end) async {
          await c.setForSelection(
            DayEntry(type: DayType.work, start: start, end: end),
          );
        },
      ),
    );
    if (context.mounted) _closeAndConfirm(context);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.dates});
  final List<DateTime> dates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRange = dates.length > 1;

    final title = isRange
        ? '${_short(dates.first)} – ${_short(dates.last)}'
        : _full(dates.first);

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(
            isRange ? Icons.date_range_rounded : Icons.event_rounded,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.headlineSmall,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded),
          color: theme.colorScheme.tertiary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  static String _full(DateTime d) {
    final s = DateFormat("EEEE d 'de' MMMM", 'es_ES').format(d);
    return s[0].toUpperCase() + s.substring(1);
  }

  static String _short(DateTime d) => DateFormat('d MMM', 'es_ES').format(d);
}

/// Chip que describe el estado actual del día y de dónde viene.
class _CurrentStateChip extends StatelessWidget {
  const _CurrentStateChip({
    required this.entry,
    required this.source,
    required this.controller,
  });

  final DayEntry? entry;
  final DayEntrySource source;
  final EmployeeScheduleController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    late final IconData icon;
    late final String label;
    late final Color color;
    String? detail;

    if (entry == null) {
      icon = Icons.remove_circle_outline_rounded;
      label = 'Sin asignar';
      color = theme.colorScheme.tertiary;
    } else {
      switch (entry!.type) {
        case DayType.work:
          icon = Icons.work_history_rounded;
          label = 'Laboral';
          color = theme.colorScheme.primary;
          if (entry!.start != null && entry!.end != null) {
            final dur = controller.workDurationOf(entry);
            detail = '${_t(entry!.start!)}–${_t(entry!.end!)}'
                '${dur != null ? ' · ${_dur(dur)}' : ''}';
          }
          break;
        case DayType.off:
          icon = Icons.free_breakfast_rounded;
          label = 'Día libre';
          color = const Color(0xff37A852);
          break;
        case DayType.vacation:
          icon = Icons.beach_access_rounded;
          label = 'Vacaciones';
          color = theme.colorScheme.error;
          break;
        case DayType.personal:
          icon = Icons.event_available_rounded;
          label = 'Asuntos propios';
          color = const Color(0xff8B5CF6);
          break;
      }
    }

    final sourceText = switch (source) {
      DayEntrySource.override => 'Editado manualmente',
      DayEntrySource.rule => 'Por horario recurrente',
      DayEntrySource.none => null,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.headlineSmall?.copyWith(color: color),
                ),
                if (detail != null)
                  Text(detail, style: theme.textTheme.bodySmall),
                if (sourceText != null)
                  Text(
                    sourceText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _t(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static String _dur(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return m == 0 ? '${h}h' : '${h}h $m min';
  }
}

class _RangeSummary extends StatelessWidget {
  const _RangeSummary({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(Icons.date_range_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count días seleccionados',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Muestra los días disponibles de vacaciones y asuntos propios del empleado.
class _LeaveBalances extends StatelessWidget {
  const _LeaveBalances({required this.controller});
  final EmployeeScheduleController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      if (!controller.balancesReady.value) {
        return const SizedBox.shrink();
      }
      return Row(
        children: [
          Expanded(
            child: _BalanceBox(
              label: 'Vacaciones',
              value: controller.vacationAvailable,
              color: theme.colorScheme.error,
              icon: Icons.beach_access_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _BalanceBox(
              label: 'Asuntos propios',
              value: controller.personalAvailable,
              color: const Color(0xff8B5CF6),
              icon: Icons.event_available_rounded,
            ),
          ),
        ],
      );
    });
  }
}

class _BalanceBox extends StatelessWidget {
  const _BalanceBox({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final double value;
  final Color color;
  final IconData icon;

  String get _valueText {
    final rounded = (value * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? '${rounded.round()}'
        : '$rounded';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.bodySmall?.copyWith(color: color),
                    overflow: TextOverflow.ellipsis),
                Text(
                  '$_valueText disp.',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: color, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: outlined ? Colors.transparent : color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: outlined ? theme.colorScheme.outline : color.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: outlined ? theme.colorScheme.tertiary : color),
              const SizedBox(width: 14),
              Text(
                label,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: outlined ? theme.colorScheme.secondary : color,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded,
                  color: theme.colorScheme.tertiary),
            ],
          ),
        ),
      ),
    );
  }
}
