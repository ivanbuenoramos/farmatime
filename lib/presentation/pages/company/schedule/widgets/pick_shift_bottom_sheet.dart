import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:farmatime/data/models/shift_template_model.dart';
import 'package:farmatime/data/models/schedule/day_entry.dart';

class PickShiftBottomSheet extends StatefulWidget {
  const PickShiftBottomSheet({
    super.key,
    required this.templates,
    required this.onApply, // devuelve (start,end)
  });

  final List<ShiftTemplate> templates;
  final void Function(TimeOfDay start, TimeOfDay end) onApply;

  @override
  State<PickShiftBottomSheet> createState() => _PickShiftBottomSheetState();
}

class _PickShiftBottomSheetState extends State<PickShiftBottomSheet> {
  ShiftTemplate? selected;
  TimeOfDay? start;
  TimeOfDay? end;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16,12,16,20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              const Icon(Icons.schedule),
              const SizedBox(width: 8),
              Text('Selecciona turno', style: Get.textTheme.titleMedium),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
            const SizedBox(height: 8),
            if (widget.templates.isEmpty)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('No hay turnos. Crea alguno en "Turnos preestablecidos".'),
              ),
            if (widget.templates.isNotEmpty)
              Column(
                children: widget.templates.map((t) {
                  final isSel = selected?.id == t.id;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: t.color != null ? Color(t.color!) : Theme.of(context).colorScheme.primaryContainer,
                      child: const Icon(Icons.schedule),
                    ),
                    title: Text(t.name),
                    subtitle: Text('${_fmt(t.startTime)}–${_fmt(t.endTime)}'
                        '${t.breakMinutes != null && t.breakMinutes! > 0 ? ' · Pausa ${t.breakMinutes}m' : ''}'),
                    trailing: isSel ? const Icon(Icons.check) : null,
                    onTap: () {
                      setState(() {
                        selected = t;
                        start = t.startTime;
                        end = t.endTime;
                      });
                    },
                  );
                }).toList(),
              ),
            const Divider(),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                icon: const Icon(Icons.tune),
                label: const Text('Manual'),
                onPressed: () async {
                  final s = await showTimePicker(context: context, initialTime: start ?? const TimeOfDay(hour: 8, minute: 0));
                  if (s == null) return;
                  final e = await showTimePicker(context: context, initialTime: end ?? const TimeOfDay(hour: 16, minute: 0));
                  if (e == null) return;
                  widget.onApply(s, e);
                  if (mounted) Navigator.pop(context);
                },
              )),
              const SizedBox(width: 8),
              Expanded(child: FilledButton.icon(
                icon: const Icon(Icons.check_circle),
                label: const Text('Aplicar turno'),
                onPressed: (start != null && end != null)
                    ? () {
                        widget.onApply(start!, end!);
                        Navigator.pop(context);
                      }
                    : null,
              )),
            ]),
            if (selected != null) ...[
              const SizedBox(height: 10),
              // Edición rápida del turno seleccionado antes de aplicar
              Row(children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () async {
                      final t = await showTimePicker(context: context, initialTime: start!);
                      if (t != null) setState(() => start = t);
                    },
                    child: Text('Inicio ${_fmt(start!)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () async {
                      final t = await showTimePicker(context: context, initialTime: end!);
                      if (t != null) setState(() => end = t);
                    },
                    child: Text('Fin ${_fmt(end!)}'),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}