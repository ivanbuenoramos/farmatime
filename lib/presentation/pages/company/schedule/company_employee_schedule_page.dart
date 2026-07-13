import 'package:farmatime/presentation/pages/company/schedule/widgets/day_action_sheet.dart';
import 'package:farmatime/presentation/pages/company/schedule/widgets/shift_templates_card.dart';
import 'package:farmatime/presentation/widgets/card/collapsible_card.dart';
import 'package:farmatime/presentation/widgets/schedule/recurring_rules_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:farmatime/data/models/schedule/day_entry.dart';
import 'package:farmatime/presentation/pages/company/schedule/company_employee_schedule_controller.dart';

class EmployeeSchedulePage extends GetView<EmployeeScheduleController> {
  const EmployeeSchedulePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _confirmLeave(context);
        if (ok && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () async {
              final ok = await _confirmLeave(context);
              if (ok && context.mounted) Navigator.of(context).pop();
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Horario'),
              if (controller.employeeName.isNotEmpty)
                Text(
                  controller.employeeName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Colors.white70,
                  ),
                ),
            ],
          ),
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _HintBanner(),
                      const SizedBox(height: 12),
                      _CalendarCard(theme: theme),
                      const SizedBox(height: 12),
                      CollapsibleCard(
                        title: 'Horario recurrente',
                        subtitle: 'Turnos que se repiten cada semana',
                        leadingIcon: Icons.repeat_rounded,
                        trailing: Obx(() => _CountBadge(controller.rules.length)),
                        child: RecurringRulesCard(),
                      ),
                      const SizedBox(height: 12),
                      CollapsibleCard(
                        title: 'Turnos preestablecidos',
                        subtitle: 'Plantillas reutilizables (Mañana, Tarde…)',
                        leadingIcon: Icons.style_rounded,
                        trailing: Obx(
                            () => _CountBadge(controller.shiftTemplates.length)),
                        child: const ShiftTemplatesCard(),
                      ),
                    ],
                  ),
                ),
              ),
              const _SaveBar(),
            ],
          );
        }),
      ),
    );
  }

  Future<bool> _confirmLeave(BuildContext context) async {
    if (!controller.hasUnsavedChanges) return true;

    final theme = Theme.of(context);
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambios sin guardar'),
        content: const Text(
          'Tienes cambios en el horario sin guardar. ¿Qué quieres hacer?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: Text('Seguir editando',
                style: TextStyle(color: theme.colorScheme.secondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: Text('Descartar',
                style: TextStyle(color: theme.colorScheme.error)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (res == 'save') {
      await controller.save();
      return !controller.hasUnsavedChanges;
    }
    return res == 'discard';
  }
}

/// Banner explicativo del flujo principal.
class _HintBanner extends StatelessWidget {
  const _HintBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.touch_app_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Toca un día para asignar turno, libre o vacaciones. '
              'Mantén pulsado para seleccionar varios días.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Tarjeta con el calendario, los selectores rápidos por día de semana y la
/// leyenda de colores.
class _CalendarCard extends GetView<EmployeeScheduleController> {
  const _CalendarCard({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: GetBuilder<EmployeeScheduleController>(
          builder: (c) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MonthHeader(theme: theme),
              const SizedBox(height: 8),
              _Calendar(theme: theme),
              const SizedBox(height: 10),
              const _WeekdayQuickSelect(),
              const Divider(height: 28),
              _Legend(theme: theme),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthHeader extends GetView<EmployeeScheduleController> {
  const _MonthHeader({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final focused = controller.focusedDay.value;
      final label = DateFormat.yMMMM('es_ES').format(focused);
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label[0].toUpperCase() + label.substring(1),
            style: theme.textTheme.headlineSmall,
          ),
          Row(
            children: [
              _RoundIconButton(
                icon: Icons.chevron_left_rounded,
                onTap: () => controller.onPageChanged(
                  DateTime(focused.year, focused.month - 1, 1),
                ),
              ),
              const SizedBox(width: 6),
              _RoundIconButton(
                icon: Icons.chevron_right_rounded,
                onTap: () => controller.onPageChanged(
                  DateTime(focused.year, focused.month + 1, 1),
                ),
              ),
            ],
          ),
        ],
      );
    });
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: theme.colorScheme.primary, size: 22),
        ),
      ),
    );
  }
}

/// Fila de selección rápida por día de la semana (L M X J V S D).
/// Selecciona todos los días de ese día de semana en el mes visible.
class _WeekdayQuickSelect extends GetView<EmployeeScheduleController> {
  const _WeekdayQuickSelect();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Material(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    controller.selectWeekdayInMonth(i + 1);
                    DayActionSheet.show(context);
                  },
                  child: SizedBox(
                    height: 34,
                    child: Center(
                      child: Text(
                        labels[i],
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _item(theme.colorScheme.primary.withValues(alpha: 0.25), 'Laboral'),
        _item(theme.colorScheme.primary.withValues(alpha: 0.10), 'Por regla'),
        _item(theme.colorScheme.tertiaryContainer.withValues(alpha: 0.35), 'Libre'),
        _item(theme.colorScheme.errorContainer.withValues(alpha: 0.45), 'Vacaciones'),
        _item(const Color(0xff8B5CF6).withValues(alpha: 0.28), 'Asuntos propios'),
      ],
    );
  }

  Widget _item(Color c, String t) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 6),
          Text(t, style: theme.textTheme.bodySmall),
        ],
      );
}

class _Calendar extends GetView<EmployeeScheduleController> {
  const _Calendar({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return TableCalendar(
        locale: 'es_ES',
        headerVisible: false,
        daysOfWeekHeight: 22,
        rowHeight: 52,
        firstDay: DateTime.utc(DateTime.now().year - 1, 1, 1),
        lastDay: DateTime.utc(DateTime.now().year + 2, 12, 31),
        focusedDay: controller.focusedDay.value,
        selectedDayPredicate: (day) => isSameDay(controller.selectedDay.value, day),
        rangeStartDay: controller.rangeStart.value,
        rangeEndDay: controller.rangeEnd.value,
        rangeSelectionMode: controller.rangeSelectionMode.value,
        availableCalendarFormats: const {CalendarFormat.month: 'Mes'},
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: theme.textTheme.bodySmall!.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.secondary,
          ),
          weekendStyle: theme.textTheme.bodySmall!.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.tertiary,
          ),
        ),
        onDaySelected: (selected, focused) {
          controller.onDaySelected(selected, focused);
          DayActionSheet.show(context);
        },
        onRangeSelected: (start, end, focused) {
          controller.onRangeSelected(start, end, focused);
          if (start != null && end != null) DayActionSheet.show(context);
        },
        onPageChanged: controller.onPageChanged,
        calendarBuilders: CalendarBuilders(
          prioritizedBuilder: (context, day, focused) {
            final isOutside = day.month != controller.focusedDay.value.month;
            final isToday = isSameDay(day, DateTime.now());
            final isSelected = isSameDay(controller.selectedDay.value, day);

            Color? outline;
            if (isSelected) {
              outline = theme.colorScheme.primary;
            } else if (isToday) {
              outline = theme.colorScheme.secondary;
            }

            final cell = _dayCell(day, theme,
                outline: outline, bold: isSelected || isToday);
            return isOutside ? Opacity(opacity: 0.4, child: cell) : cell;
          },
        ),
      );
    });
  }

  Widget _dayCell(DateTime day, ThemeData theme, {Color? outline, bool bold = false}) {
    final c = Get.find<EmployeeScheduleController>();
    final entry = c.computedEntryFor(day);
    final bg = c.colorFor(day, theme);
    final dur = c.workDurationOf(entry);

    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: outline != null ? Border.all(color: outline, width: 1.5) : null,
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: theme.colorScheme.secondary,
            ),
          ),
          if (dur != null)
            Text(
              _fmtDuration(dur),
              style: const TextStyle(fontSize: 9, color: Color(0xff6B7280)),
            )
          else if (entry?.type == DayType.vacation)
            Icon(Icons.beach_access_rounded,
                size: 11, color: theme.colorScheme.error)
          else if (entry?.type == DayType.off)
            const Icon(Icons.free_breakfast_rounded,
                size: 11, color: Color(0xff37A852))
          else if (entry?.type == DayType.personal)
            const Icon(Icons.event_available_rounded,
                size: 11, color: Color(0xff8B5CF6)),
        ],
      ),
    );
  }

  static String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return m == 0 ? '${h}h' : '${h}h$m';
  }
}

/// Barra inferior fija que aparece solo cuando hay cambios sin guardar.
class _SaveBar extends GetView<EmployeeScheduleController> {
  const _SaveBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      final dirty = controller.dirtyMonths.length;
      final saving = controller.isSaving.value;
      if (dirty == 0 && !saving) return const SizedBox.shrink();

      return Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: theme.colorScheme.outline)),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Icon(Icons.edit_calendar_rounded,
                    color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dirty == 1
                        ? 'Cambios en 1 mes sin guardar'
                        : 'Cambios en $dirty meses sin guardar',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: saving ? null : controller.save,
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(saving ? 'Guardando…' : 'Guardar'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(120, 44),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
