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

// ▼ imports NUEVOS (solicitudes de ausencia)
import 'package:farmatime/domain/repositories/time_off_repository.dart';
import 'package:farmatime/data/repositories/time_off_repository_impl.dart';
import 'package:farmatime/domain/usecases/time_off/stream_time_off_by_employee_usecase.dart';
import 'package:farmatime/domain/usecases/time_off/decide_time_off_usecase.dart';
import 'package:farmatime/domain/usecases/time_off/find_time_off_overlaps_usecase.dart';

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

    // Solicitudes de ausencia (NUEVO)
    Get.lazyPut<TimeOffRepository>(() => TimeOffRepositoryImpl());
    Get.lazyPut<StreamTimeOffByEmployeeUseCase>(
      () => StreamTimeOffByEmployeeUseCase(Get.find<TimeOffRepository>()),
    );
    Get.lazyPut<DecideTimeOffUseCase>(
      () => DecideTimeOffUseCase(Get.find<TimeOffRepository>()),
    );
    Get.lazyPut<FindTimeOffOverlapsUseCase>(
      () => FindTimeOffOverlapsUseCase(Get.find<TimeOffRepository>()),
    );

    // Controller
    Get.lazyPut(() => EmployeeDetailController(
      getEntriesByEmployeeUseCase: Get.find<GetEntriesByEmployeeUseCase>(),
      streamMonthScheduleUseCase: Get.find<StreamEmployeeMonthScheduleUseCase>(),
      streamRecurringRulesUseCase: Get.find<StreamRecurringRulesUseCase>(),
      streamTimeOffByEmployeeUseCase: Get.find<StreamTimeOffByEmployeeUseCase>(),
      decideTimeOffUseCase: Get.find<DecideTimeOffUseCase>(),
      findTimeOffOverlapsUseCase: Get.find<FindTimeOffOverlapsUseCase>(),
    ));
  }
}
