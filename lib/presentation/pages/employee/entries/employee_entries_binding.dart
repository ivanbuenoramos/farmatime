
import 'package:farmatime/data/repositories/clock_repository_impl.dart';
import 'package:farmatime/domain/repositories/clock_repository.dart';
import 'package:farmatime/domain/usecases/clock/get_entries_by_employee_usecase.dart';
import 'package:farmatime/presentation/pages/employee/entries/employee_entries_controller.dart';
import 'package:get/get.dart';


class EmployeeEntriesBinding extends Bindings {
  @override
  void dependencies() {

    Get.lazyPut<ClockRepository>(() => ClockRepositoryImpl());

    Get.lazyPut<GetEntriesByEmployeeUseCase>(
      () => GetEntriesByEmployeeUseCase(Get.find<ClockRepository>()),
    );
    
    Get.lazyPut(() => (EmployeeEntriesController(
      getEntriesByEmployeeUseCase: Get.find<GetEntriesByEmployeeUseCase>(),
    )));
  }
}
