import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/domain/usecases/clock/update_entry_usecase.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import 'package:farmatime/data/models/clock_in_out_model.dart';
import 'package:farmatime/data/models/clock_audit_log_model.dart';

class EditEntryController extends GetxController {
  
  final ClockInOutModel originalEntry;
  final UpdateEntryUseCase updateEntryUseCase;

  EditEntryController({
    required this.originalEntry,
    required this.updateEntryUseCase,
  });

  // Estado editable
  late Rx<DateTime> clockIn;
  late Rxn<DateTime> clockOut;

  final TextEditingController reasonController = TextEditingController();

  final RxBool isSaving = false.obs;
  final RxnString errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    clockIn = originalEntry.clockIn.obs;
    reasonController.text = originalEntry.editReason ?? '';
    clockOut = Rxn<DateTime>(originalEntry.clockOut);
  }

  Future<void> pickClockIn(BuildContext context) async {
    final current = clockIn.value;
    final timeOfDay = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (timeOfDay == null) return;

    clockIn.value = DateTime(
      current.year,
      current.month,
      current.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );
  }

  Future<void> pickClockOut(BuildContext context) async {
    final base = clockOut.value ?? clockIn.value;
    final timeOfDay = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: base.hour, minute: base.minute),
    );
    if (timeOfDay == null) return;

    // La salida se ancla al día de la ENTRADA. Si la hora elegida es anterior o
    // igual a la de entrada, el turno cruza medianoche y la salida cae el día
    // siguiente (turnos nocturnos). Así no se generan duraciones negativas.
    final inDt = clockIn.value;
    var out = DateTime(
      inDt.year,
      inDt.month,
      inDt.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );
    if (!out.isAfter(inDt)) {
      out = out.add(const Duration(days: 1));
    }
    clockOut.value = out;
  }

  Future<void> onSave() async {
    errorMessage.value = null;

    final reason = reasonController.text.trim();
    if (reason.isEmpty) {
      errorMessage.value = 'Debes indicar un motivo para la edición';
      return;
    }

    // Coherencia: la salida (si existe) debe ser posterior a la entrada. Para
    // turnos nocturnos, pickClockOut ya empuja la salida al día siguiente.
    final out = clockOut.value;
    if (out != null && !out.isAfter(clockIn.value)) {
      errorMessage.value =
          'La hora de salida debe ser posterior a la de entrada';
      return;
    }

    // No permitimos fichajes en el futuro.
    if (clockIn.value.isAfter(DateTime.now()) ||
        (out != null && out.isAfter(DateTime.now()))) {
      errorMessage.value = 'El fichaje no puede estar en el futuro';
      return;
    }

    // Detectar qué campos han cambiado y registrar su valor antes/después.
    final List<String> editedFields = [];
    final List<ClockAuditChange> changes = [];

    if (!isSameDateTime(clockIn.value, originalEntry.clockIn)) {
      editedFields.add('clockIn');
      changes.add(ClockAuditChange(
        field: 'clockIn',
        oldValue: originalEntry.clockIn,
        newValue: clockIn.value,
      ));
    }

    final originalOut = originalEntry.clockOut;
    final currentOut = clockOut.value;
    final bool outChanged = (originalOut == null && currentOut != null) ||
        (originalOut != null && currentOut == null) ||
        (originalOut != null &&
            currentOut != null &&
            !isSameDateTime(originalOut, currentOut));

    if (outChanged) {
      editedFields.add('clockOut');
      changes.add(ClockAuditChange(
        field: 'clockOut',
        oldValue: originalOut,
        newValue: currentOut,
      ));
    }

    // Si no cambia ningún valor, no tiene sentido registrar una edición.
    if (editedFields.isEmpty) {
      errorMessage.value = 'No has modificado ningún horario';
      return;
    }

    final now = DateTime.now();

    // Mezclamos campos ya marcados como editados con los nuevos (los campos
    // denormalizados del fichaje reflejan el ÚLTIMO cambio; el histórico
    // completo vive en la subcolección auditLog).
    final mergedEditedFields = <String>{
      ...originalEntry.editedFields,
      ...editedFields,
    }.toList();

    final updatedEntry = originalEntry.copyWith(
      clockIn: clockIn.value,
      clockOut: clockOut.value,
      isEdited: true,
      editedBy: 'company',
      editedAt: now,
      editReason: reason,
      editedFields: mergedEditedFields,
      updatedAt: now,
    );

    // Construimos la entrada inmutable del log de auditoría.
    final brain = Brain();
    final company = brain.company.value;
    final auditLog = ClockAuditLogModel(
      id: const Uuid().v4(),
      entryId: originalEntry.id,
      companyId: originalEntry.companyId,
      employeeId: originalEntry.employeeId,
      action: ClockAuditAction.edited,
      actorUid: company?.id ?? 'unknown',
      actorRole: 'company',
      actorName: company?.legalName,
      reason: reason,
      changes: changes,
      at: now,
    );

    isSaving.value = true;
    try {
      final result = await updateEntryUseCase(updatedEntry, auditLog: auditLog);

      if (result.success && result.data != null) {
        Get.back(result: result.data);
      } else {
        errorMessage.value = 'Error al actualizar el fichaje';
      }
    } catch (e) {
      errorMessage.value = 'Error inesperado: $e';
    } finally {
      isSaving.value = false;
    }
  }

  bool isSameDateTime(DateTime a, DateTime b) {
    return a.millisecondsSinceEpoch == b.millisecondsSinceEpoch;
  }

  @override
  void onClose() {
    reasonController.dispose();
    super.onClose();
  }
}