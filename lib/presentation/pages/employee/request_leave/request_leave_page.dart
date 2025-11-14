// lib/presentation/pages/leave/request/request_leave_page.dart
import 'package:farmatime/presentation/widgets/card/base_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'request_leave_controller.dart';

class RequestLeavePage extends GetView<RequestLeaveController> {
  const RequestLeavePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const pad = EdgeInsets.all(16.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitar vacaciones y permisos'),
        titleSpacing: 0,
      ),
      bottomNavigationBar: Obx(() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outline),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
            ),
          ],
        ),
        child: SafeArea(
          child: FilledButton.icon(
            onPressed: controller.isValid && !controller.submitting.value
                ? controller.submit
                : null,
            icon: controller.submitting.value
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: Text(controller.submitting.value ? 'Enviando…' : 'Enviar solicitud'),
          ),
        ),
      )),
      body: Obx(() {
        final type = controller.leaveType.value;
        final s = controller.startDate.value;
        final e = controller.endDate.value;
        final total = controller.totalDays;
        final mode = controller.selectionMode.value;
        final selectedDays = controller.selectedDays;

        return SingleChildScrollView(
          padding: pad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tipo de solicitud
              BaseCard(
                title: 'Tipo de solicitud',
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Vacaciones'),
                        selected: type == LeaveType.vacaciones,
                        selectedColor: Colors.redAccent,
                        onSelected: (_) => controller.setLeaveType(LeaveType.vacaciones),
                      ),
                      ChoiceChip(
                        label: const Text('Asuntos propios'),
                        selected: type == LeaveType.personales,
                        selectedColor: Theme.of(context).colorScheme.tertiary,
                        disabledColor: theme.colorScheme.error,
                        onSelected: (_) => controller.setLeaveType(LeaveType.personales),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Modo de selección
              BaseCard(
                title: 'Modo de selección',
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Rango de fechas'),
                        selectedColor: Theme.of(context).colorScheme.primary,
                        selected: mode == LeaveSelectionMode.range,
                        onSelected: (_) => controller.setSelectionMode(LeaveSelectionMode.range),
                      ),
                      ChoiceChip(
                        label: const Text('Días sueltos'),
                        selectedColor: Theme.of(context).colorScheme.primary,
                        selected: mode == LeaveSelectionMode.multiple,
                        onSelected: (_) => controller.setSelectionMode(LeaveSelectionMode.multiple),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // UI según modo
              if (mode == LeaveSelectionMode.range)
                BaseCard(
                  title: 'Rango de fechas',
                  children: [
                    _RangePickerTile(
                      start: s,
                      end: e,
                      onTap: () => controller.pickRange(context),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Puedes seleccionar también un día único eligiendo la misma fecha de inicio y fin.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                )
              else
                BaseCard(
                  title: 'Días sueltos',
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final d in selectedDays)
                          _DayChip(
                            date: d,
                            onDeleted: () => controller.removeDay(d),
                          ),
                        ActionChip(
                          avatar: const Icon(Icons.add),
                          label: const Text('Añadir día'),
                          onPressed: () => controller.pickSingleDay(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Selecciona uno o varios días no consecutivos. Puedes eliminar un día pulsando la “x”.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),

              const SizedBox(height: 12),

              // Comentario opcional
              BaseCard(
                title: 'Comentario opcional',
                children: [
                  TextField(
                    controller: controller.noteCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Añade información útil para tu responsable…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Resumen
              _SummaryCard(
                typeLabel: type == LeaveType.vacaciones ? 'Vacaciones' : 'Asuntos propios',
                start: s,
                end: e,
                totalDays: total,
                mode: mode,
                multipleDays: selectedDays,
              ),

              const SizedBox(height: 20),
            ],
          ),
        );
      }),
    );
  }
}

class _RangePickerTile extends StatelessWidget {
  final DateTime? start;
  final DateTime? end;
  final VoidCallback onTap;

  const _RangePickerTile({
    required this.start,
    required this.end,
    required this.onTap,
  });

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasRange = start != null && end != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.date_range),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasRange
                  ? '${_fmt(start!)}  —  ${_fmt(end!)}'
                  : 'Selecciona un rango de fechas (o mismo día en inicio y fin)',
                style: theme.textTheme.bodyLarge,
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String typeLabel;
  final DateTime? start;
  final DateTime? end;
  final int totalDays;
  final LeaveSelectionMode mode;
  final List<DateTime> multipleDays;

  const _SummaryCard({
    required this.typeLabel,
    required this.start,
    required this.end,
    required this.totalDays,
    required this.mode,
    required this.multipleDays,
  });

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BaseCard(
      title: 'Resumen',
      children: [
        const SizedBox(height: 8),
        _Row('Tipo', typeLabel),
        if (mode == LeaveSelectionMode.range) ...[
          _Row('Inicio', start != null ? _fmt(start!) : '—'),
          _Row('Fin', end != null ? _fmt(end!) : '—'),
        ] else ...[
          _Row('Días seleccionados', multipleDays.isEmpty ? '—' : ''),
          if (multipleDays.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: multipleDays
                  .map((d) => Chip(label: Text(_fmt(d))))
                  .toList(),
              ),
            ),
        ],
        const Divider(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total de días', style: theme.textTheme.bodyLarge),
            Text(
              totalDays > 0 ? '$totalDays' : '—',
              style: theme.textTheme.headlineSmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  final DateTime date;
  final VoidCallback onDeleted;
  const _DayChip({required this.date, required this.onDeleted});

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return InputChip(
      selectedColor: Theme.of(context).colorScheme.primary,
      label: Text(_fmt(date)),
      onDeleted: onDeleted,
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}