import 'package:farmatime/data/repositories/clock_repository_impl.dart';
import 'package:farmatime/domain/repositories/clock_repository.dart';
import 'package:farmatime/domain/usecases/clock/get_company_clock_records_usecase.dart';
import 'package:farmatime/domain/usecases/clock/get_employee_day_clock_records_usecase.dart';
import 'package:get/get.dart';

import 'package:farmatime/presentation/pages/company/entries/company_entries_controller.dart';



class CompanyEntriesBinding extends Bindings {
  @override
  void dependencies() {
    // Repo
    Get.lazyPut<ClockRepository>(
      () => ClockRepositoryImpl(),
    );

    // Usecases
    Get.lazyPut(
      () => GetCompanyClockRecordsUseCase(Get.find<ClockRepository>()),
    );
    Get.lazyPut(
      () =>
          GetEmployeeDayClockRecordsUseCase(Get.find<ClockRepository>()),
    );

    // Controller
    Get.lazyPut(
      () => CompanyEntriesController(
        getCompanyClockRecordsUseCase: Get.find(),
        getEmployeeDayClockRecordsUseCase: Get.find(),
      ),
    );
  }
}