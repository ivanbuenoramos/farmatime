import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:farmatime/data/models/shift_template_model.dart';
import 'package:farmatime/presentation/pages/company/shift_templates/shift_templates_controller.dart';

class ShiftTemplatesPage extends GetView<ShiftTemplatesController> {
  const ShiftTemplatesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Turnos preestablecidos')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context),
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, size: 48, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  const Text(
                    'Aún no tienes turnos.\nCrea tu primer turno con el botón +',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: controller.items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final t = controller.items[index];
            return _ShiftTile(
              template: t,
              onEdit: () => _openForm(context, initial: t),
              onDelete: () => _confirmDelete(context, t),
            );
          },
        );
      }),
    );
  }

  Future<void> _openForm(BuildContext context, {ShiftTemplate? initial}) async {
    final result = await showDialog<ShiftTemplate>(
      context: context,
      builder: (_) => _ShiftTemplateDialog(initial: initial),
    );
    if (result == null) return;

    if (initial == null) {
      await controller.create(result);
    } else {
      await controller.updateTemplate(result);
    }
  }

  Future<void> _confirmDelete(BuildContext context, ShiftTemplate t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar turno'),
        content: Text('¿Seguro que quieres eliminar "${t.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await controller.deleteTemplate(t.id);
    }
  }
}

class _ShiftTile extends StatelessWidget {
  const _ShiftTile({
    required this.template,
    required this.onEdit,
    required this.onDelete,
  });

  final ShiftTemplate template;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = template.color != null
        ? Color(template.color!)
        : theme.colorScheme.primaryContainer;

    return Card(
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        leading: CircleAvatar(
          backgroundColor: color,
          child: const Icon(Icons.schedule),
        ),
        title: Text(template.name),
        subtitle: Text(
          '${_fmt(template.startTime)} – ${_fmt(template.endTime)}'
          '${template.breakMinutes != null && template.breakMinutes! > 0 ? ' · Pausa ${template.breakMinutes}m' : ''}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Editar'))),
            PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Eliminar'))),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _ShiftTemplateDialog extends StatefulWidget {
  const _ShiftTemplateDialog({this.initial});
  final ShiftTemplate? initial;

  @override
  State<_ShiftTemplateDialog> createState() => _ShiftTemplateDialogState();
}

class _ShiftTemplateDialogState extends State<_ShiftTemplateDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  TimeOfDay? _start;
  TimeOfDay? _end;
  int? _breakMinutes;
  int? _color; // ARGB int

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    _start = widget.initial?.startTime ?? const TimeOfDay(hour: 8, minute: 0);
    _end = widget.initial?.endTime ?? const TimeOfDay(hour: 16, minute: 0);
    _breakMinutes = widget.initial?.breakMinutes;
    _color = widget.initial?.color;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.initial == null ? 'Nuevo turno' : 'Editar turno'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Nombre
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Nombre del turno',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe un nombre' : null,
              ),
              const SizedBox(height: 12),

              // Horas
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.play_circle),
                      label: Text('Inicio ${_fmt(_start!)}'),
                      onPressed: () async {
                        final t = await showTimePicker(context: context, initialTime: _start!);
                        if (t != null) setState(() => _start = t);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.stop_circle),
                      label: Text('Fin ${_fmt(_end!)}'),
                      onPressed: () async {
                        final t = await showTimePicker(context: context, initialTime: _end!);
                        if (t != null) setState(() => _end = t);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Pausa (opcional)
              TextFormField(
                initialValue: _breakMinutes?.toString() ?? '',
                decoration: const InputDecoration(
                  labelText: 'Minutos de pausa (opcional)',
                  hintText: 'Ej: 30',
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final parsed = int.tryParse(v);
                  _breakMinutes = parsed;
                },
              ),
              const SizedBox(height: 12),

              // Color rápido (paleta simple)
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Color', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _palette.map((c) {
                  final selected = _color == c.value;
                  return GestureDetector(
                    onTap: () => setState(() => _color = c.value),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? theme.colorScheme.primary : Colors.black12,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check, size: 18, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final out = (widget.initial ?? ShiftTemplate.empty()).copyWith(
              name: _name.text.trim(),
              start: _fmt(_start!),
              end: _fmt(_end!),
              breakMinutes: _breakMinutes,
              color: _color,
            );
            Navigator.pop(context, out);
          },
          child: Text(widget.initial == null ? 'Crear' : 'Guardar'),
        ),
      ],
    );
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // Paleta breve (puedes ampliarla)
  static const List<Color> _palette = [
    Color(0xFF1971FF),
    Color(0xFF00B894),
    Color(0xFFFF7675),
    Color(0xFFFFC107),
    Color(0xFF6C5CE7),
    Color(0xFF00BCD4),
    Color(0xFF8D6E63),
    Color(0xFF455A64),
  ];
}