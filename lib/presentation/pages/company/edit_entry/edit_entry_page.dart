import 'package:farmatime/domain/usecases/clock/update_entry_usecase.dart';
import 'package:farmatime/presentation/pages/company/edit_entry/edit_entry_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:farmatime/data/models/clock_in_out_model.dart';

class EditEntryModal extends StatelessWidget {
  final ClockInOutModel entry;

  const EditEntryModal({
    super.key,
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<EditEntryController>(
      init: EditEntryController(
        originalEntry: entry,
        updateEntryUseCase: Get.find<UpdateEntryUseCase>(),
      ),
      builder: (controller) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Obx(
              () => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Editar fichaje',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Entrada
                  _DateTimeRow(
                    label: 'Entrada',
                    dateTime: controller.clockIn.value,
                    onTap: () => controller.pickClockIn(context),
                  ),
                  const SizedBox(height: 8),

                  // Salida
                  _DateTimeRow(
                    label: 'Salida',
                    dateTime: controller.clockOut.value,
                    onTap: () => controller.pickClockOut(context),
                    nullable: true,
                  ),
                  const SizedBox(height: 16),

                  // Motivo
                  TextField(
                    controller: controller.reasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Motivo de la edición',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  if (controller.errorMessage.value != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      controller.errorMessage.value!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                            controller.isSaving.value ? null : () => Get.back(),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: controller.isSaving.value
                            ? null
                            : () => controller.onSave(),
                        child: controller.isSaving.value
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Guardar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DateTimeRow extends StatelessWidget {
  final String label;
  final DateTime? dateTime;
  final VoidCallback onTap;
  final bool nullable;

  const _DateTimeRow({
    required this.label,
    required this.dateTime,
    required this.onTap,
    this.nullable = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final String valueText;
    if (dateTime == null) {
      valueText = nullable ? 'Sin salida registrada' : '—';
    } else {
      final d = dateTime!;
      valueText =
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} · '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: Theme.of(context).dividerColor.withOpacity(0.6)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              valueText,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.edit, size: 18),
          ],
        ),
      ),
    );
  }
}