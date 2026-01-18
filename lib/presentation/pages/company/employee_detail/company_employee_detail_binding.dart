// lib/presentation/pages/company/employee_detail/company_employee_detail_binding.dart
import 'package:farmatime/data/repositories/clock_repository_impl.dart';
import 'package:farmatime/domain/repositories/clock_repository.dart';
import 'package:farmatime/domain/usecases/clock/get_entries_by_employee_usecase.dart';
import 'package:farmatime/domain/usecases/employee_schedule/stream_employee_month_schedule_usecase.dart';
import 'package:farmatime/domain/usecases/employee_schedule/stream_recurring_rules_usecase.dart';
import 'package:get/get.dart';
import 'package:farmatime/presentation/pages/company/employee_detail/company_employee_detail_controller.dart';

// ▼ imports NUEVOS (horario)
import 'package:farmatime/domain/repositories/employee_schedule_repository.dart';
import 'package:farmatime/data/repositories/employee_schedule_repository_impl.dart';

class EmployeeDetailBinding extends Bindings {
  @override
  void dependencies() {

    // Clock
    Get.lazyPut<ClockRepository>(() => ClockRepositoryImpl());
    
    Get.lazyPut<GetEntriesByEmployeeUseCase>(
      () => GetEntriesByEmployeeUseCase(Get.find<ClockRepository>()),
    );

    // Horario (NUEVO)
    Get.lazyPut<EmployeeScheduleRepository>(() => EmployeeScheduleRepositoryImpl());
    
    Get.lazyPut<StreamEmployeeMonthScheduleUseCase>(
      () => StreamEmployeeMonthScheduleUseCase(Get.find<EmployeeScheduleRepository>()),
    );
    Get.lazyPut<StreamRecurringRulesUseCase>(
      () => StreamRecurringRulesUseCase(Get.find<EmployeeScheduleRepository>()),
    );

    // Controller
    Get.lazyPut(() => EmployeeDetailController(
      getEntriesByEmployeeUseCase: Get.find<GetEntriesByEmployeeUseCase>(),
      streamMonthScheduleUseCase: Get.find<StreamEmployeeMonthScheduleUseCase>(),
      streamRecurringRulesUseCase: Get.find<StreamRecurringRulesUseCase>(),
    ));
  }
}
