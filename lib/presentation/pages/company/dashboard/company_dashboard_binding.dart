// lib/presentation/pages/company/dashboard/company_dashboard_binding.dart
import 'package:farmatime/data/repositories/clock_repository_impl.dart';
import 'package:farmatime/data/repositories/employee_repository_impl.dart';
import 'package:farmatime/data/repositories/employee_schedule_repository_impl.dart';
import 'package:farmatime/domain/repositories/clock_repository.dart';
import 'package:farmatime/domain/repositories/employee_repository.dart';
import 'package:farmatime/domain/repositories/employee_schedule_repository.dart';
import 'package:farmatime/domain/usecases/employee/get_employees_by_company_id_usecase.dart';
import 'package:farmatime/domain/usecases/employee_schedule/get_expected_shift_usecase.dart';
import 'package:get/get.dart';

import 'company_dashboard_controller.dart';
import 'package:farmatime/domain/usecases/clock/get_today_last_clocks_usecase.dart';



class CompanyDashboardBinding extends Bindings {
  @override
  void dependencies() {
    
    Get.lazyPut<ClockRepository>(() => ClockRepositoryImpl());

    Get.lazyPut<EmployeeRepository>(() => EmployeeRepositoryImpl());

    Get.lazyPut<EmployeeScheduleRepository>(() => EmployeeScheduleRepositoryImpl());

    Get.put(GetEmployeesByCompanyIdUseCase(Get.find<EmployeeRepository>()));
    Get.put(GetTodayLastClocksUseCase(Get.find<ClockRepository>()));
    Get.put(GetExpectedShiftUseCase(Get.find<EmployeeScheduleRepository>()));

    Get.put(CompanyDashboardController(
      getEmployeesByCompany: Get.find(),
      getTodayLastClocks: Get.find(),
      getExpectedShiftsToday: Get.find(),
    ));
  }
}
