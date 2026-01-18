// lib/presentation/pages/company/dashboard/company_dashboard_binding.dart
import 'package:farmatime/data/repositories/clock_repository_impl.dart';
import 'package:farmatime/data/repositories/employee_repository_impl.dart';
import 'package:farmatime/data/repositories/employee_schedule_repository_impl.dart';
import 'package:farmatime/domain/repositories/clock_repository.dart';
import 'package:farmatime/domain/repositories/employee_repository.dart';
import 'package:farmatime/domain/repositories/employee_schedule_repository.dart';
import 'package:farmatime/domain/usecases/clock/stream_today_last_clocks_usecase.dart';
import 'package:farmatime/domain/usecases/employee_schedule/get_expected_shift_usecase.dart';
import 'package:get/get.dart';

import 'company_dashboard_controller.dart';



class CompanyDashboardBinding extends Bindings {
  @override
  void dependencies() {
    
    Get.lazyPut<ClockRepository>(() => ClockRepositoryImpl());

    Get.lazyPut<EmployeeRepository>(() => EmployeeRepositoryImpl());

    Get.lazyPut<EmployeeScheduleRepository>(() => EmployeeScheduleRepositoryImpl());

    Get.put(GetExpectedShiftsForDayUseCase(Get.find<EmployeeScheduleRepository>()));

    Get.put(StreamTodayLastClocksUseCase(Get.find<ClockRepository>()));

    Get.put(CompanyDashboardController(
      streamTodayLastClocksUseCase: Get.find(),
      getExpectedShiftsForDayUseCase: Get.find(),
    ));
  }
}
