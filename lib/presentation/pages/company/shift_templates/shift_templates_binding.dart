import 'package:get/get.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/domain/repositories/shift_template_repository.dart';
import 'package:farmatime/data/repositories/shift_template_repository_impl.dart';
import 'package:farmatime/domain/usecases/shift_template/upsert_shift_template_usecase.dart';
import 'package:farmatime/presentation/pages/company/shift_templates/shift_templates_controller.dart';

// UseCases
import 'package:farmatime/domain/usecases/shift_template/list_shift_templates_usecase.dart';
import 'package:farmatime/domain/usecases/shift_template/delete_shift_template_usecase.dart';

class ShiftTemplatesBinding extends Bindings {
  @override
  void dependencies() {

    Get.lazyPut<ShiftTemplateRepository>(() => ShiftTemplateRepositoryImpl());
    
    // UseCases
    Get.lazyPut<ListShiftTemplatesUseCase>(
      () => ListShiftTemplatesUseCase(Get.find<ShiftTemplateRepository>()),
    );
    Get.lazyPut<UpsertShiftTemplateUseCase>(
      () => UpsertShiftTemplateUseCase(Get.find<ShiftTemplateRepository>()),
    );
    Get.lazyPut<DeleteShiftTemplateUseCase>(
      () => DeleteShiftTemplateUseCase(Get.find<ShiftTemplateRepository>()),
    );


    Get.lazyPut<ShiftTemplatesController>(() => ShiftTemplatesController(
      listUC: Get.find<ListShiftTemplatesUseCase>(),
      upsertUC: Get.find<UpsertShiftTemplateUseCase>(),
      deleteUC: Get.find<DeleteShiftTemplateUseCase>(),
      brain: Get.find<Brain>(),
    ));
  }
}