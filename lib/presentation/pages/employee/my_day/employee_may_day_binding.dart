import 'package:get/get.dart';

import 'package:farmatime/domain/repositories/clock_repository.dart';
import 'package:farmatime/data/repositories/clock_repository_impl.dart';
import 'package:farmatime/domain/usecases/clock/update_entry_usecase.dart';
import 'package:farmatime/domain/usecases/clock/create_entry_usecase.dart';
import 'package:farmatime/domain/usecases/clock/get_current_entry_usecase.dart';
import 'package:farmatime/domain/usecases/clock/get_entries_by_employee_usecase.dart';
import 'package:farmatime/presentation/pages/employee/my_day/employee_may_day_controller.dart';



class EmployeeMyDayBinding extends Bindings {
  @override
  void dependencies() {

    Get.lazyPut<ClockRepository>(() => ClockRepositoryImpl());

    Get.lazyPut<GetCurrentEntryUseCase>(
      () => GetCurrentEntryUseCase(Get.find<ClockRepository>()),
    );

    Get.lazyPut<UpdateEntryUseCase>(
      () => UpdateEntryUseCase(Get.find<ClockRepository>()),
    );

    Get.lazyPut<GetEntriesByEmployeeUseCase>(
      () => GetEntriesByEmployeeUseCase(Get.find<ClockRepository>()),
    );

    Get.lazyPut<CreateEntryUseCase>(
      () => CreateEntryUseCase(Get.find<ClockRepository>()),
    );

    Get.lazyPut(() => EmployeeMyDayController(
      createEntryUseCase: Get.find<CreateEntryUseCase>(),
      updateEntryUseCase: Get.find<UpdateEntryUseCase>(),
      getCurrentEntryUseCase: Get.find<GetCurrentEntryUseCase>(),
      getEntriesByEmployeeUseCase: Get.find<GetEntriesByEmployeeUseCase>(),
    ));
  }
}
