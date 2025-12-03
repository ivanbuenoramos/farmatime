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
        return Obx(
          () => Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(20),
            color: Get.theme.colorScheme.surface,
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle superior
                  const SizedBox(height: 8),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Get.theme.colorScheme.outline.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                
                  // Header con título y botón cerrar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Editar fichaje',
                                style: Get.theme.textTheme.headlineMedium
                              ),
                            ),
                            GestureDetector(
                              onTap: controller.isSaving.value
                                 ? null
                                : () => Get.back(),
                              child: Icon(
                                Icons.close_rounded,
                                size: 32,
                                color: Get.theme.colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                        Divider(),
                        Text(
                          'Por normativa laboral es obligatorio indicar un motivo al modificar un fichaje.',
                          style: Get.theme.textTheme.bodyMedium
                        ),
                      ],
                    ),
                  ),
                
                  const SizedBox(height: 8),
                
                  // Info de última edición (si la hay)
                  if (controller.originalEntry.isEdited) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Get.theme.colorScheme.outline,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Get.theme.colorScheme.outline.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.warning_rounded,
                                  size: 22,
                                  color: Get.theme.colorScheme.tertiary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Este fichaje ya ha sido editado',
                                  style: Get.theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (controller.originalEntry.editedAt != null)
                              Text(
                                'Última edición: '
                                '${_formatDateTime(controller.originalEntry.editedAt!)}',
                                style:Get.theme.textTheme.bodySmall,
                              ),
                            if (controller.originalEntry.editedBy != null)
                              Text(
                                'Editado por ${controller.originalEntry.editedBy == 'company' ? 'farmacia' : 'empleado'}',
                                style: Get.theme.textTheme.bodySmall,
                              ),
                            if (controller.originalEntry.editedFields
                                .isNotEmpty)
                              Text(
                                'Campos modificados: '
                                '${controller.originalEntry.editedFields.join(', ')}',
                                style: Get.theme.textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                
                  // Contenido scrollable
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Entrada
                          _DateTimeRow(
                            label: 'Hora de entrada',
                            dateTime: controller.clockIn.value,
                            onTap: () => controller.pickClockIn(context),
                          ),
                          const SizedBox(height: 10),
                
                          // Salida
                          _DateTimeRow(
                            label: 'Hora de salida',
                            dateTime: controller.clockOut.value,
                            onTap: () => controller.pickClockOut(context),
                            nullable: true,
                          ),
                          const SizedBox(height: 16),
                
                          // Motivo
                          TextField(
                            controller: controller.reasonController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Motivo de la edición',
                              alignLabelWithHint: true,
                            ),
                          ),
                
                          if (controller.errorMessage.value != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              controller.errorMessage.value!,
                              style: TextStyle(
                                color: Get.theme.colorScheme.error,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                
                  const SizedBox(height: 8),
                
                  // Botones de acción
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: controller.isSaving.value
                              ? null
                              : () => controller.onSave(),
                            icon: controller.isSaving.value
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_rounded, size: 18),
                            label: const Text('Guardar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _formatDateTime(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} '
        '${two(d.hour)}:${two(d.minute)}';
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
    final textTheme = Get.theme.textTheme;
    final colorScheme = Get.theme.colorScheme;

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
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.schedule_rounded,
              size: 18,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 10),
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
            Icon(
              Icons.edit_outlined,
              size: 18,
              color: colorScheme.onSurface.withOpacity(0.8),
            ),
          ],
        ),
      ),
    );
  }
}