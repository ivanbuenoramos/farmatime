import 'package:farmatime/presentation/pages/company/schedule/widgets/pick_shift_bottom_sheet.dart';
import 'package:farmatime/presentation/pages/company/schedule/widgets/shift_templates_card.dart';
import 'package:farmatime/presentation/widgets/schedule/recurring_rules_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:farmatime/data/models/schedule/day_entry.dart';
import 'package:farmatime/presentation/widgets/card/base_card.dart';
import 'package:farmatime/presentation/pages/company/schedule/company_employee_schedule_controller.dart';



class EmployeeSchedulePage extends GetView<EmployeeScheduleController> {
  const EmployeeSchedulePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Get.theme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Horario del empleado'),
        actions: [
          Obx(() => IconButton(
                onPressed: controller.isSaving.value ? null : controller.save,
                icon: controller.isSaving.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                tooltip: 'Guardar',
              )),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            children: [

              // CRUD de turnos preestablecidos
              // const ShiftTemplatesCard(),
              // const SizedBox(height: 12),

              BaseCard(
                title: 'Horario recurrente',
                description:
                    'Define turnos semanales con fin opcional. Los overrides del calendario tienen prioridad.',
                children: [
                  RecurringRulesCard(),
                ],
              ),
              const SizedBox(height: 12),

              GetBuilder<EmployeeScheduleController>(
                builder: (c) => BaseCard(
                  title: 'Calendario',
                  children: [
                    _Calendar(theme: theme),
                    Wrap(
                      spacing: 15,
                      runSpacing: 0,
                      children: [
                        _legendItem(theme.colorScheme.primary.withOpacity(0.25), 'Laboral'),
                        _legendItem(theme.colorScheme.tertiaryContainer.withOpacity(0.35), 'Libre'),
                        _legendItem(theme.colorScheme.errorContainer.withOpacity(0.45), 'Vacaciones'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Acciones',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Divider(height: 12),
                    _Actions(theme: theme),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      }),
    );
  }

  Widget _legendItem(Color c, String t) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 16,
        height: 16,
        decoration:BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))
      ),
      const SizedBox(width: 4),
      Text(t),
    ]
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
        firstDay: DateTime.utc(DateTime.now().year - 1, 1, 1),
        lastDay: DateTime.utc(DateTime.now().year + 2, 12, 31),
        focusedDay: controller.focusedDay.value,
        selectedDayPredicate: (day) => isSameDay(controller.selectedDay.value, day),
        rangeStartDay: controller.rangeStart.value,
        rangeEndDay: controller.rangeEnd.value,
        rangeSelectionMode: controller.rangeSelectionMode.value,
        availableCalendarFormats: const {CalendarFormat.month: 'Mes'},
        onDaySelected: controller.onDaySelected,
        onRangeSelected: controller.onRangeSelected,
        onPageChanged: (focused) async {
          controller.focusedDay.value = focused;
          await controller.loadYear(focused.year);
        },
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focused) => _dayCell(day, theme),
          outsideBuilder: (context, day, focused) =>
              Opacity(opacity: 0.4, child: _dayCell(day, theme)),
          todayBuilder: (context, day, focused) =>
              _dayCell(day, theme, outline: theme.colorScheme.secondary),
          selectedBuilder: (context, day, focused) =>
              _dayCell(day, theme, outline: theme.colorScheme.primary, bold: true),
        ),
      );
    });
  }

  Widget _dayCell(DateTime day, ThemeData theme, {Color? outline, bool bold = false}) {
    final c = Get.find<EmployeeScheduleController>().colorFor(day, theme);
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(10),
        border: outline != null ? Border.all(color: outline, width: 1.5) : null,
      ),
      alignment: Alignment.center,
      child: Text('${day.day}',
          style:
              TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
    );
  }
}

class _Actions extends GetView<EmployeeScheduleController> {
  const _Actions({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        // Al pulsar, abre BottomSheet de turnos (con edición rápida) y aplica
        FilledButton.icon(
          onPressed: () => _applyWorkWithTemplate(context),
          icon: const Icon(Icons.work_history_rounded),
          label: const Text('Asignar turno'),
        ),
        FilledButton.icon(
          onPressed: () => controller.setForSelection(DayEntry(type: DayType.off)),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.tertiaryContainer,
            foregroundColor: theme.colorScheme.onTertiaryContainer,
          ),
          icon: const Icon(Icons.event_busy_rounded),
          label: const Text('Marcar libre'),
        ),
        FilledButton.icon(
          onPressed: () => controller.setForSelection(DayEntry(type: DayType.vacation)),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.redAccent,
          ),
          icon: const Icon(Icons.beach_access_rounded),
          label: const Text('Marcar vacaciones'),
        ),
        TextButton.icon(
          onPressed: controller.clearSelection,
          icon: const Icon(Icons.undo_rounded),
          label: const Text('Quitar asignación'),
        ),
      ],
    );
  }

  Future<void> _applyWorkWithTemplate(BuildContext context) async {
    // Si no hay turnos todavía, ofrece crear manual
    if (controller.shiftTemplates.isEmpty) {
      final from = await showTimePicker(
          context: context, initialTime: const TimeOfDay(hour: 8, minute: 0));
      if (from == null) return;
      final to = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 16, minute: 0));
      if (to == null) return;
      await controller.setForSelection(DayEntry(type: DayType.work, start: from, end: to));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => PickShiftBottomSheet(
        templates: controller.shiftTemplates,
        onApply: (start, end) async {
          await controller
              .setForSelection(DayEntry(type: DayType.work, start: start, end: end));
        },
      ),
    );
  }
}