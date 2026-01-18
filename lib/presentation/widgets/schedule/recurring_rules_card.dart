import 'package:farmatime/domain/usecases/employee_schedule/delete_recurring_rule_usecase.dart';
import 'package:farmatime/domain/usecases/employee_schedule/upsert_recurring_rule_usecase.dart';
import 'package:farmatime/presentation/pages/company/schedule/company_employee_schedule_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:farmatime/presentation/widgets/card/base_card.dart';
import 'package:farmatime/data/models/schedule/recurring_shift_rule.dart';
import 'package:farmatime/presentation/widgets/schedule/weekday_selector.dart';

class RecurringRulesCard extends GetView<EmployeeScheduleController> {
  const RecurringRulesCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _RuleForm(),
        const SizedBox(height: 12),
        Obx(() {
          if (controller.rules.isEmpty) return const Text('Sin reglas definidas');
          return Column(
            children: controller.rules
                .map((r) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${_fmtTod(r.startTime)}–${_fmtTod(r.endTime)} · ${_weekdaysLabel(r.weekdays)}',
                      ),
                      subtitle: Text(
                        'Desde ${_date(r.startsOn)}${r.endsOn != null ? ' · Hasta ${_date(r.endsOn!)}' : ''}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteRule(r),
                      ),
                    ))
                .toList(),
          );
        }),
      ],
    );
  }

  static String _fmtTod(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _weekdaysLabel(List<int> days) {
    const names = {1: 'L', 2: 'M', 3: 'X', 4: 'J', 5: 'V', 6: 'S', 7: 'D'};
    return (days.toList()..sort()).map((e) => names[e]).join('');
  }

  Future<void> _deleteRule(RecurringShiftRule r) async {
    final c = Get.find<EmployeeScheduleController>();
    final res = await Get.find<DeleteRecurringShiftRuleUseCase>().call(
      companyId: c.brain.company.value!.id,
      employeeId: c.employeeId,
      ruleId: r.id,
    );
    if (res.success) {
      await c.loadRules();
    } else {
      Get.snackbar('Error', 'No se pudo eliminar la regla',
          snackPosition: SnackPosition.BOTTOM);
    }
  }
}

class _RuleForm extends StatefulWidget {
  const _RuleForm();

  @override
  State<_RuleForm> createState() => _RuleFormState();
}

class _RuleFormState extends State<_RuleForm> {
  TimeOfDay start = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay end = const TimeOfDay(hour: 16, minute: 0);

  final Set<int> weekdays = {1, 2, 3, 4, 5};

  DateTime startsOn = DateTime.now();
  DateTime? endsOn;
  bool forever = true;

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      title: 'Nueva regla',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: () async {
                final t = await showTimePicker(context: context, initialTime: start);
                if (t != null) setState(() => start = t);
              },
              child: Text('Inicio ${start.format(context)}'),
            ),
            FilledButton.tonal(
              onPressed: () async {
                final t = await showTimePicker(context: context, initialTime: end);
                if (t != null) setState(() => end = t);
              },
              child: Text('Fin ${end.format(context)}'),
            ),
          ],
        ),
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

        const SizedBox(height: 8),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: startsOn,
                  firstDate: DateTime.now().subtract(const Duration(days: 3650)),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                  locale: const Locale('es', 'ES'),
                );
                if (picked != null) setState(() => startsOn = picked);
              },
              icon: const Icon(Icons.event),
              label: Text('Empieza: ${_date(startsOn)}'),
            ),

            Row(
              children: [
                Checkbox(
                  value: forever,
                  onChanged: (v) => setState(() {
                    forever = v ?? true;
                    if (forever) endsOn = null;
                  }),
                ),
                const Text('Sin fecha fin'),
              ],
            ),

            if (!forever)
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: endsOn ?? startsOn.add(const Duration(days: 30)),
                    firstDate: startsOn,
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                    locale: const Locale('es', 'ES'),
                  );
                  if (picked != null) setState(() => endsOn = picked);
                },
                child: Text('Fin: ${endsOn != null ? _date(endsOn!) : '--/--/----'}'),
              ),
          ],
        ),

        const SizedBox(height: 8),

        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            icon: const Icon(Icons.save_rounded),
            label: const Text('Guardar regla'),
            onPressed: _saveRule,
          ),
        ),
      ],
    );
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _saveRule() async {
    try {
      if (weekdays.isEmpty) {
        Get.snackbar('Selecciona días', 'Elige al menos un día de la semana');
        return;
      }

      // Validación mínima: fin no puede ser igual o antes que inicio
      final startMins = start.hour * 60 + start.minute;
      final endMins = end.hour * 60 + end.minute;
      if (startMins == endMins) {
        Get.snackbar('Horas inválidas', 'Inicio y fin no pueden ser iguales');
        return;
      }

      final c = Get.find<EmployeeScheduleController>();

      final rule = RecurringShiftRule(
        id: '', // upsert creará id si está vacío
        weekdays: weekdays.toList()..sort(),
        start: start.toString(),
        end: end.toString(),
        startsOn: DateTime(startsOn.year, startsOn.month, startsOn.day),
        endsOn: (forever || endsOn == null)
            ? null
            : DateTime(endsOn!.year, endsOn!.month, endsOn!.day),
        active: true,
      );

      final uc = Get.find<UpsertRecurringShiftRuleUseCase>();
      final res = await uc.call(
        rule: rule, 
        companyId: c.brain.company.value!.id,
        employeeId: c.employeeId,
      );

      if (!res.success) {
        Get.snackbar(
          'Error al guardar',
          res.errorCode ?? 'desconocido',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      await c.loadRules();

      Get.snackbar(
        'Regla guardada',
        'Horario recurrente actualizado',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e, st) {
      debugPrint('saveRule error: $e\n$st');
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    }
  }
}