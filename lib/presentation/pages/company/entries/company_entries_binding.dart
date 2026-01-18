import 'package:farmatime/data/repositories/clock_repository_impl.dart';
import 'package:farmatime/data/repositories/employee_repository_impl.dart';
import 'package:farmatime/domain/repositories/clock_repository.dart';
import 'package:farmatime/domain/repositories/employee_repository.dart';
import 'package:farmatime/domain/usecases/clock/get_company_clock_records_usecase.dart';
import 'package:farmatime/domain/usecases/clock/get_employee_day_clock_records_usecase.dart';
import 'package:farmatime/domain/usecases/clock/stream_company_clock_records_usecase.dart';
import 'package:farmatime/domain/usecases/employee/get_employees_by_company_id_usecase.dart';
import 'package:get/get.dart';

import 'package:farmatime/presentation/pages/company/entries/company_entries_controller.dart';



class CompanyEntriesBinding extends Bindings {
  @override
  void dependencies() {
    // Repo
    Get.lazyPut<ClockRepository>(
      () => ClockRepositoryImpl(),
    );

    Get.lazyPut<EmployeeRepository>(
      () => EmployeeRepositoryImpl(),
    );

    // Usecases
    Get.lazyPut(
      () => GetCompanyClockRecordsUseCase(Get.find<ClockRepository>()),
    );
    Get.lazyPut(
      () => GetEmployeeDayClockRecordsUseCase(Get.find<ClockRepository>()),
    );

    Get.lazyPut(
      () => GetEmployeesByCompanyIdUseCase(Get.find<EmployeeRepository>()),
    );
    
    Get.lazyPut(() => StreamCompanyClockRecordsUseCase(Get.find<ClockRepository>()));


    // Controller
    Get.lazyPut(
      () => CompanyEntriesController(
        getEmployeeDayClockRecordsUseCase: Get.find(),
        getEmployeesByCompanyIdUseCase: Get.find(),
        streamCompanyClockRecordsUseCase: Get.find(),
      ),
    );
  }
}