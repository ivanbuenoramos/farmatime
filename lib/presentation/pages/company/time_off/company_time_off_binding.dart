import 'package:get/get.dart';

import 'package:farmatime/data/repositories/time_off_repository_impl.dart';
import 'package:farmatime/domain/repositories/time_off_repository.dart';
import 'package:farmatime/domain/usecases/time_off/stream_time_off_by_company_usecase.dart';
import 'package:farmatime/domain/usecases/time_off/decide_time_off_usecase.dart';
import 'package:farmatime/domain/usecases/time_off/find_time_off_overlaps_usecase.dart';

import 'company_time_off_controller.dart';

class CompanyTimeOffBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TimeOffRepository>(() => TimeOffRepositoryImpl());

    Get.lazyPut<StreamTimeOffByCompanyUseCase>(
      () => StreamTimeOffByCompanyUseCase(Get.find<TimeOffRepository>()),
    );
    Get.lazyPut<DecideTimeOffUseCase>(
      () => DecideTimeOffUseCase(Get.find<TimeOffRepository>()),
    );
    Get.lazyPut<FindTimeOffOverlapsUseCase>(
      () => FindTimeOffOverlapsUseCase(Get.find<TimeOffRepository>()),
    );

    Get.lazyPut<CompanyTimeOffController>(
      () => CompanyTimeOffController(
        streamByCompanyUseCase: Get.find<StreamTimeOffByCompanyUseCase>(),
        decideTimeOffUseCase: Get.find<DecideTimeOffUseCase>(),
        findTimeOffOverlapsUseCase: Get.find<FindTimeOffOverlapsUseCase>(),
      ),
    );
  }
}
