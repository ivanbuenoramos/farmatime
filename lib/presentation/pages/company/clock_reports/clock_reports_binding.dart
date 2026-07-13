import 'package:farmatime/data/repositories/clock_report_repository_impl.dart';
import 'package:farmatime/domain/repositories/clock_report_repository.dart';
import 'package:farmatime/domain/usecases/clock_reports/get_company_reports_by_month_use_case.dart';
import 'package:get/get.dart';

import 'clock_reports_controller.dart';

class ClockReportsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ClockReportRepository>(
      () => ClockReportRepositoryImpl(),
    );
    Get.lazyPut(
      () => GetCompanyReportsByMonthUseCase(Get.find()),
    );
    Get.lazyPut<ClockReportsController>(
      () => ClockReportsController(
        getCompanyReportsByMonthUseCase: Get.find(),
      ),
    );
  }
}
