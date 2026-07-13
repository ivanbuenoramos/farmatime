import 'package:farmatime/core/routes/routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:farmatime/data/models/shift_template_model.dart';

/// Hoja para elegir un turno preestablecido y aplicarlo a la selección.
/// Tocar un turno lo aplica al instante. "Horario manual" permite horas libres.
class PickShiftBottomSheet extends StatelessWidget {
  const PickShiftBottomSheet({
    super.key,
    required this.templates,
    required this.onApply,
  });

  final List<ShiftTemplate> templates;
  final void Function(TimeOfDay start, TimeOfDay end) onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
            Row(
              children: [
                Text('Elige un turno', style: theme.textTheme.headlineMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  color: theme.colorScheme.tertiary,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (templates.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No hay turnos guardados. Usa el horario manual o crea turnos.',
                  style: theme.textTheme.bodySmall,
                ),
              )
            else
              for (final t in templates) ...[
                _ShiftTile(
                  template: t,
                  onTap: () {
                    onApply(t.startTime, t.endTime);
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 8),
              ],

            const SizedBox(height: 4),

            // Horario manual (horas libres).
            OutlinedButton.icon(
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Horario manual'),
              onPressed: () => _pickManual(context),
            ),
            const SizedBox(height: 8),

            // Gestionar turnos (CRUD de plantillas).
            Center(
              child: TextButton.icon(
                icon: Icon(Icons.settings_rounded,
                    size: 18, color: theme.colorScheme.primary),
                label: Text(
                  'Gestionar turnos',
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
                onPressed: () => Get.toNamed(Routes.companyShiftTemplates),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickManual(BuildContext context) async {
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: 'Hora de inicio',
    );
    if (start == null || !context.mounted) return;

    final end = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 16, minute: 0),
      helpText: 'Hora de fin',
    );
    if (end == null) return;

    onApply(start, end);
    if (context.mounted) Navigator.pop(context);
  }
}

class _ShiftTile extends StatelessWidget {
  const _ShiftTile({required this.template, required this.onTap});
  final ShiftTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent =
        template.color != null ? Color(template.color!) : theme.colorScheme.primary;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 36,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(template.name, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${_fmt(template.startTime)}–${_fmt(template.endTime)}'
                      ' · ${template.totalDurationLabel}'
                      '${template.breakMinutes != null && template.breakMinutes! > 0 ? ' · pausa ${template.breakMinutes}m' : ''}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.tertiary),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
