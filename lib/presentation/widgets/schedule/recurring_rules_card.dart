import 'package:farmatime/domain/usecases/employee_schedule/delete_recurring_rule_usecase.dart';
import 'package:farmatime/domain/usecases/employee_schedule/upsert_recurring_rule_usecase.dart';
import 'package:farmatime/core/services/toast_service.dart';
import 'package:farmatime/presentation/pages/company/schedule/company_employee_schedule_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:farmatime/data/models/schedule/recurring_shift_rule.dart';
import 'package:farmatime/presentation/widgets/schedule/weekday_selector.dart';

class RecurringRulesCard extends GetView<EmployeeScheduleController> {
  const RecurringRulesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Obx(() {
          if (controller.rules.isEmpty) {
            return _EmptyState(theme: theme);
          }
          return Column(
            children: [
              for (final r in controller.rules) ...[
                _RuleTile(rule: r),
                if (r != controller.rules.last) const SizedBox(height: 8),
              ],
            ],
          );
        }),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _openRuleEditor(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Añadir regla'),
        ),
      ],
    );
  }

  Future<void> _openRuleEditor(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _RuleEditorSheet(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.event_repeat_rounded,
              color: theme.colorScheme.tertiary, size: 28),
          const SizedBox(height: 8),
          Text(
            'Sin reglas recurrentes',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.secondary),
          ),
          const SizedBox(height: 2),
          Text(
            'Ej.: lunes a viernes, 08:00–16:00',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({required this.rule});
  final RecurringShiftRule rule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, color: theme.colorScheme.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_fmtTod(rule.startTime)}–${_fmtTod(rule.endTime)}',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 2),
                _WeekdayDots(weekdays: rule.weekdays.toSet()),
                const SizedBox(height: 4),
                Text(
                  'Desde ${_date(rule.startsOn)}'
                  '${rule.endsOn != null ? ' · hasta ${_date(rule.endsOn!)}' : ' · sin fin'}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
            onPressed: () => _confirmDelete(context, rule),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, RecurringShiftRule r) async {
    final theme = Theme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar regla'),
        content: const Text('¿Quieres eliminar esta regla de horario recurrente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar',
                style: TextStyle(color: theme.colorScheme.secondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final c = Get.find<EmployeeScheduleController>();
    final res = await Get.find<DeleteRecurringShiftRuleUseCase>().call(
      companyId: c.brain.company.value!.id,
      employeeId: c.employeeId,
      ruleId: r.id,
    );
    if (res.success) {
      await c.loadRules();
    } else {
      ToastService().show(
          title: 'Error',
          message: 'No se pudo eliminar la regla',
          type: ToastType.error);
    }
  }

  static String _fmtTod(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// Muestra los 7 días de la semana resaltando los activos de la regla.
class _WeekdayDots extends StatelessWidget {
  const _WeekdayDots({required this.weekdays});
  final Set<int> weekdays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: weekdays.contains(i + 1)
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: weekdays.contains(i + 1)
                      ? Colors.white
                      : theme.colorScheme.tertiary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RuleEditorSheet extends StatefulWidget {
  const _RuleEditorSheet();

  @override
  State<_RuleEditorSheet> createState() => _RuleEditorSheetState();
}

class _RuleEditorSheetState extends State<_RuleEditorSheet> {
  TimeOfDay start = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay end = const TimeOfDay(hour: 16, minute: 0);
  final Set<int> weekdays = {1, 2, 3, 4, 5};
  DateTime startsOn = DateTime.now();
  DateTime? endsOn;
  bool forever = true;
  bool saving = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Nueva regla recurrente', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                'Define un turno que se repite en los días elegidos.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 20),

              // Horas
              Text('Horario', style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _TimeField(
                      label: 'Inicio',
                      time: start,
                      onTap: () async {
                        final t = await showTimePicker(
                            context: context, initialTime: start);
                        if (t != null) setState(() => start = t);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeField(
                      label: 'Fin',
                      time: end,
                      onTap: () async {
                        final t = await showTimePicker(
                            context: context, initialTime: end);
                        if (t != null) setState(() => end = t);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Días
              Text('Días de la semana', style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              WeekdaySelector(
                value: weekdays,
                onChanged: (d) => setState(() {
                  if (weekdays.contains(d)) {
                    weekdays.remove(d);
                  } else {
                    weekdays.add(d);
                  }
                }),
              ),
              const SizedBox(height: 20),

              // Vigencia
              Text('Vigencia', style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              _DateField(
                label: 'Empieza',
                value: _date(startsOn),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: startsOn,
                    firstDate: DateTime.now().subtract(const Duration(days: 3650)),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                    locale: const Locale('es', 'ES'),
                  );
                  if (picked != null) setState(() => startsOn = picked);
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sin fecha de fin'),
                value: forever,
                onChanged: (v) => setState(() {
                  forever = v;
                  if (forever) endsOn = null;
                }),
              ),
              if (!forever) ...[
                const SizedBox(height: 4),
                _DateField(
                  label: 'Termina',
                  value: endsOn != null ? _date(endsOn!) : 'Elegir fecha',
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: endsOn ?? startsOn.add(const Duration(days: 30)),
                      firstDate: startsOn,
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                      locale: const Locale('es', 'ES'),
                    );
                    if (picked != null) setState(() => endsOn = picked);
                  },
                ),
              ],
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: saving ? null : () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: saving ? null : _saveRule,
                      child: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Guardar regla'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _saveRule() async {
    if (weekdays.isEmpty) {
      ToastService().show(
          title: 'Selecciona días',
          message: 'Elige al menos un día de la semana',
          type: ToastType.warning);
      return;
    }
    final startMins = start.hour * 60 + start.minute;
    final endMins = end.hour * 60 + end.minute;
    if (startMins == endMins) {
      ToastService().show(
          title: 'Horas inválidas',
          message: 'Inicio y fin no pueden ser iguales',
          type: ToastType.error);
      return;
    }

    setState(() => saving = true);
    try {
      final c = Get.find<EmployeeScheduleController>();
      final rule = RecurringShiftRule(
        id: '',
        weekdays: weekdays.toList()..sort(),
        start: start.toString(),
        end: end.toString(),
        startsOn: DateTime(startsOn.year, startsOn.month, startsOn.day),
        endsOn: (forever || endsOn == null)
            ? null
            : DateTime(endsOn!.year, endsOn!.month, endsOn!.day),
        active: true,
      );

      final res = await Get.find<UpsertRecurringShiftRuleUseCase>().call(
        rule: rule,
        companyId: c.brain.company.value!.id,
        employeeId: c.employeeId,
      );

      if (!res.success) {
        debugPrint('saveRule failed: ${res.errorCode}');
        ToastService().show(
            title: 'Error al guardar',
            message: 'No se pudo guardar el horario. Inténtalo de nuevo.',
            type: ToastType.error);
        return;
      }

      await c.loadRules();
      if (mounted) Navigator.pop(context);
      ToastService().show(
          title: 'Regla guardada',
          message: 'Horario recurrente actualizado',
          type: ToastType.success);
    } catch (e, st) {
      debugPrint('saveRule error: $e\n$st');
      ToastService().show(
          title: 'Error',
          message: 'No se pudo guardar el horario. Inténtalo de nuevo.',
          type: ToastType.error);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({required this.label, required this.time, required this.onTap});
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded,
                size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall),
                Text(text, style: theme.textTheme.headlineSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Row(
          children: [
            Icon(Icons.event_rounded, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Text(label, style: theme.textTheme.bodyMedium),
            const Spacer(),
            Text(value, style: theme.textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
