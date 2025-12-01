import 'package:farmatime/domain/usecases/clock/update_entry_usecase.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:farmatime/data/models/clock_in_out_model.dart';

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

    clockOut.value = DateTime(
      base.year,
      base.month,
      base.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );
  }

  Future<void> onSave() async {
    errorMessage.value = null;

    // Detectar qué campos han cambiado
    final List<String> editedFields = [];

    if (!isSameDateTime(clockIn.value, originalEntry.clockIn)) {
      editedFields.add('clockIn');
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
    }

    // Si no cambia nada, simplemente cerramos
    if (editedFields.isEmpty &&
        reasonController.text.trim().isEmpty &&
        originalEntry.isEdited) {
      Get.back(result: originalEntry);
      return;
    }

    final now = DateTime.now();
    final reason = reasonController.text.trim();

    // Mezclamos campos ya marcados como editados con los nuevos
    final mergedEditedFields = <String>{
      ...originalEntry.editedFields,
      ...editedFields,
    }.toList();

    final updatedEntry = originalEntry.copyWith(
      clockIn: clockIn.value,
      clockOut: clockOut.value,
      isEdited: mergedEditedFields.isNotEmpty || originalEntry.isEdited,
      editedBy: 'company',
      editedAt: now,
      editReason: reason.isNotEmpty ? reason : originalEntry.editReason,
      editedFields: mergedEditedFields,
      updatedAt: now,
    );

    isSaving.value = true;
    try {
      final result = await updateEntryUseCase(updatedEntry);

      // Ajusta estos nombres a tu implementación real de Result
      final bool success =
          // ignore: avoid_dynamic_calls
          (result as dynamic).success ?? false;
      final ClockInOutModel? data =
          // ignore: avoid_dynamic_calls
          (result as dynamic).data as ClockInOutModel?;

      if (success && data != null) {
        Get.back(result: data);
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