// lib/presentation/pages/employee/calendar/employee_calendar_binding.dart
import 'package:get/get.dart';
import 'employee_calendar_controller.dart';
import 'package:farmatime/domain/repositories/employee_schedule_repository.dart';
import 'package:farmatime/data/repositories/employee_schedule_repository_impl.dart';

class EmployeeCalendarBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<EmployeeScheduleRepository>(() => EmployeeScheduleRepositoryImpl());
    Get.put(EmployeeCalendarController(Get.find<EmployeeScheduleRepository>()));
  }
}
