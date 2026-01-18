// lib/presentation/pages/employee/calendar/employee_calendar_binding.dart
import 'package:farmatime/domain/usecases/employee_schedule/get_employee_month_schedule_usecase.dart';
import 'package:farmatime/domain/usecases/employee_schedule/list_recurring_rules_usecase.dart';
import 'package:get/get.dart';
import 'employee_calendar_controller.dart';
import 'package:farmatime/domain/repositories/employee_schedule_repository.dart';
import 'package:farmatime/data/repositories/employee_schedule_repository_impl.dart';

class EmployeeCalendarBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<EmployeeScheduleRepository>(() => EmployeeScheduleRepositoryImpl());
    Get.lazyPut<GetEmployeeMonthScheduleUseCase>(
      () => GetEmployeeMonthScheduleUseCase(Get.find<EmployeeScheduleRepository>()),
    );
    Get.lazyPut<ListRecurringRulesUseCase>(
      () => ListRecurringRulesUseCase(Get.find<EmployeeScheduleRepository>()),
    );
    
    Get.lazyPut(() => EmployeeCalendarController(
      getMonthScheduleUseCase: Get.find<GetEmployeeMonthScheduleUseCase>(),
      listRecurringRulesUseCase: Get.find<ListRecurringRulesUseCase>(),
    ));
  }
}
