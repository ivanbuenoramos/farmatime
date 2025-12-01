// lib/presentation/pages/company/employee_detail/company_employee_detail_binding.dart
import 'package:farmatime/data/models/clock_in_out_model.dart';
import 'package:farmatime/data/repositories/clock_repository_impl.dart';
import 'package:farmatime/domain/repositories/clock_repository.dart';
import 'package:farmatime/domain/usecases/clock/update_entry_usecase.dart';
import 'package:farmatime/presentation/pages/company/edit_entry/edit_entry_controller.dart';
import 'package:get/get.dart';


class EditEntryBinding extends Bindings {
  @override
  void dependencies() {

    // Clock
    Get.lazyPut<ClockRepository>(() => ClockRepositoryImpl());
    
    Get.lazyPut<UpdateEntryUseCase>(
      () => UpdateEntryUseCase(Get.find<ClockRepository>()),
    );

    Get.lazyPut(() => EditEntryController(
      updateEntryUseCase: Get.find<UpdateEntryUseCase>(),
      originalEntry: Get.arguments as ClockInOutModel,
    ));
  }
}
