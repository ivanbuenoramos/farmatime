import 'package:farmatime/domain/usecases/shift_template/upsert_shift_template_usecase.dart';
import 'package:get/get.dart';
import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/shift_template_model.dart';
import 'package:farmatime/core/services/toast_service.dart';

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
      ToastService().show(title: 'Error', message: error.value!, type: ToastType.error);
    }
  }

  Future<bool> create(ShiftTemplate t) async {
    isSaving.value = true;
    final Result<String?> res = await upsertUC.call(t);
    isSaving.value = false;

    if (!res.success) {
      ToastService().show(title: 'Error', message: 'No se pudo crear el turno', type: ToastType.error);
      return false;
    }
    await load();
    ToastService().show(title: 'Turno creado', message: t.name, type: ToastType.success);
    return true;
  }

  Future<bool> updateTemplate(ShiftTemplate t) async {
    isSaving.value = true;
    final res = await upsertUC.call(t);
    isSaving.value = false;

    if (!res.success) {
      ToastService().show(title: 'Error', message: 'No se pudo actualizar', type: ToastType.error);
      return false;
    }
    await load();
    ToastService().show(title: 'Turno actualizado', message: t.name, type: ToastType.success);
    return true;
  }

  Future<bool> deleteTemplate(String id) async {
    isSaving.value = true;
    final res = await deleteUC.call(id);
    isSaving.value = false;

    if (!res.success) {
      ToastService().show(title: 'Error', message: 'No se pudo eliminar', type: ToastType.error);
      return false;
    }
    items.removeWhere((e) => e.id == id);
    ToastService().show(title: 'Eliminado', message: 'Turno eliminado', type: ToastType.success);
    return true;
  }
}