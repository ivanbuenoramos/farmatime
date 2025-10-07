import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/shift_template_model.dart';
import 'package:farmatime/domain/usecases/shift_template/list_shift_templates_usecase.dart';
import 'package:farmatime/domain/usecases/shift_template/upsert_shift_template_usecase.dart';
import 'package:farmatime/domain/usecases/shift_template/delete_shift_template_usecase.dart';
import 'package:farmatime/presentation/widgets/card/base_card.dart';
import 'package:farmatime/data/models/schedule/day_entry.dart';

class ShiftTemplatesCard extends StatefulWidget {
  const ShiftTemplatesCard({super.key});

  @override
  State<ShiftTemplatesCard> createState() => _ShiftTemplatesCardState();
}

class _ShiftTemplatesCardState extends State<ShiftTemplatesCard> {
  final Brain brain = Get.find<Brain>();
  final templates = <ShiftTemplate>[].obs;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => loading = true);
    final uc = Get.find<ListShiftTemplatesUseCase>();
    final res = await uc.call(brain.company.value!.id);
    if (res.success) templates.assignAll(res.data);
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      title: 'Turnos preestablecidos',
      description: 'Crea turnos (ej. Mañana 08:00–16:00) para aplicarlos rápido en el calendario.',
      children: [
        if (loading) const Padding(
          padding: EdgeInsets.all(8.0),
          child: Center(child: CircularProgressIndicator()),
        ),
        if (!loading)
          Obx(() {
            if (templates.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Aún no hay turnos. Crea el primero.'),
              );
            }
            return Column(
              children: templates.map((t) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: t.color != null ? Color(t.color!) : Theme.of(context).colorScheme.primaryContainer,
                  child: const Icon(Icons.schedule),
                ),
                title: Text(t.name),
                subtitle: Text('${_fmt(DayEntry.fromHHmm(t.start))}–${_fmt(DayEntry.fromHHmm(t.end))}'
                    '${t.breakMinutes != null && t.breakMinutes! > 0 ? ' · Pausa ${t.breakMinutes}m' : ''}'),
                trailing: Wrap(
                  spacing: 6,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _openEditor(template: t),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(t),
                    ),
                  ],
                ),
              )).toList(),
            );
          }),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add),
            label: const Text('Nuevo turno'),
          ),
        ),
      ],
    );
  }

  Future<void> _delete(ShiftTemplate t) async {
    final uc = Get.find<DeleteShiftTemplateUseCase>();
    final res = await uc.call(t.id);
    if (res.success) await _reload();
  }

  Future<void> _openEditor({ShiftTemplate? template}) async {
    final nameCtrl = TextEditingController(text: template?.name ?? '');
    TimeOfDay start = template?.startTime ?? const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay end = template?.endTime ?? const TimeOfDay(hour: 16, minute: 0);
    final pauseCtrl = TextEditingController(text: (template?.breakMinutes ?? 0).toString());
    int? color = template?.color;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(template == null ? 'Nuevo turno' : 'Editar turno'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(decoration: const InputDecoration(labelText: 'Nombre'), controller: nameCtrl),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () async {
                      final t = await showTimePicker(context: ctx, initialTime: start);
                      if (t != null) { start = t; (ctx as Element).markNeedsBuild(); }
                    },
                    child: Text('Inicio ${_fmt(start)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () async {
                      final t = await showTimePicker(context: ctx, initialTime: end);
                      if (t != null) { end = t; (ctx as Element).markNeedsBuild(); }
                    },
                    child: Text('Fin ${_fmt(end)}'),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              TextField(
                controller: pauseCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Pausa (min) - opcional'),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final c in _palette)
                  GestureDetector(
                    onTap: () { color = c.value; (ctx as Element).markNeedsBuild(); },
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: c,
                      child: color == c.value ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                    ),
                  ),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final brain = Get.find<Brain>();
              final upsert = Get.find<UpsertShiftTemplateUseCase>();
              final t = ShiftTemplate(
                id: template?.id ?? '',
                companyId: brain.company.value!.id,
                name: nameCtrl.text.trim().isEmpty ? 'Turno' : nameCtrl.text.trim(),
                start: DayEntry.toHHmm(start),
                end: DayEntry.toHHmm(end),
                breakMinutes: int.tryParse(pauseCtrl.text.trim()),
                color: color,
                active: true,
              );
              final res = await upsert.call(t);
              if (res.success) {
                Navigator.pop(ctx);
                await _reload();
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static const _palette = <Color>[
    Color(0xFF4F46E5), Color(0xFF06B6D4), Color(0xFF10B981),
    Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF8B5CF6),
  ];
}