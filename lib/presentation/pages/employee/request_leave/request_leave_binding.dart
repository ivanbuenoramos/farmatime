import 'package:get/get.dart';

import 'package:farmatime/data/repositories/time_off_repository_impl.dart';
import 'package:farmatime/domain/repositories/time_off_repository.dart';
import 'package:farmatime/domain/usecases/time_off/create_time_off_usecase.dart';
import 'package:farmatime/domain/usecases/time_off/decide_time_off_usecase.dart';
import 'package:farmatime/domain/usecases/time_off/stream_time_off_by_employee_usecase.dart';

import 'request_leave_controller.dart';

class RequestLeaveBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TimeOffRepository>(() => TimeOffRepositoryImpl());

    Get.lazyPut<CreateTimeOffUseCase>(
      () => CreateTimeOffUseCase(Get.find<TimeOffRepository>()),
    );
    Get.lazyPut<StreamTimeOffByEmployeeUseCase>(
      () => StreamTimeOffByEmployeeUseCase(Get.find<TimeOffRepository>()),
    );
    Get.lazyPut<DecideTimeOffUseCase>(
      () => DecideTimeOffUseCase(Get.find<TimeOffRepository>()),
    );

    Get.lazyPut<RequestLeaveController>(
      () => RequestLeaveController(
        createTimeOffUseCase: Get.find<CreateTimeOffUseCase>(),
        streamByEmployeeUseCase: Get.find<StreamTimeOffByEmployeeUseCase>(),
        decideTimeOffUseCase: Get.find<DecideTimeOffUseCase>(),
      ),
    );
  }
}
