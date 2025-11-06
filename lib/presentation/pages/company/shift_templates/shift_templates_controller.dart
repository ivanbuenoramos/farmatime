import 'package:farmatime/domain/usecases/shift_template/upsert_shift_template_usecase.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/shift_template_model.dart';

// UseCases
import 'package:farmatime/domain/usecases/shift_template/list_shift_templates_usecase.dart';
import 'package:farmatime/domain/usecases/shift_template/delete_shift_template_usecase.dart';

class ShiftTemplatesController extends GetxController {
  ShiftTemplatesController({
    required this.listUC,
    required this.upsertUC,
    required this.deleteUC,
    required this.brain,
  });

  final ListShiftTemplatesUseCase listUC;
  final UpsertShiftTemplateUseCase upsertUC;
  final DeleteShiftTemplateUseCase deleteUC;
  final Brain brain;

  final RxList<ShiftTemplate> items = <ShiftTemplate>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxnString error = RxnString();

  String get _companyId => brain.company.value!.id;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    error.value = null;
    isLoading.value = true;
    final res = await listUC.call(_companyId);
    isLoading.value = false;

    if (res.success) {
      items.assignAll(res.data);
    } else {
      error.value = 'No se pudieron cargar los turnos';
      Get.snackbar('Error', error.value!,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.08));
    }
  }

  Future<bool> create(ShiftTemplate t) async {
    isSaving.value = true;
    final Result<String?> res = await upsertUC.call(t);
    isSaving.value = false;

    if (!res.success) {
      Get.snackbar('Error', 'No se pudo crear el turno',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.08));
      return false;
    }
    await load();
    Get.snackbar('Turno creado', t.name, snackPosition: SnackPosition.BOTTOM);
    return true;
  }

  Future<bool> updateTemplate(ShiftTemplate t) async {
    isSaving.value = true;
    final res = await upsertUC.call(t);
    isSaving.value = false;

    if (!res.success) {
      Get.snackbar('Error', 'No se pudo actualizar',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.08));
      return false;
    }
    await load();
    Get.snackbar('Turno actualizado', t.name, snackPosition: SnackPosition.BOTTOM);
    return true;
  }

  Future<bool> deleteTemplate(String id) async {
    isSaving.value = true;
    final res = await deleteUC.call(id);
    isSaving.value = false;

    if (!res.success) {
      Get.snackbar('Error', 'No se pudo eliminar',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.08));
      return false;
    }
    items.removeWhere((e) => e.id == id);
    Get.snackbar('Eliminado', 'Turno eliminado', snackPosition: SnackPosition.BOTTOM);
    return true;
  }
}