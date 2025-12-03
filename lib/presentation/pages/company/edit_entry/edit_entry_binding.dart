import 'package:get/get.dart';

import 'package:farmatime/domain/repositories/clock_repository.dart';
import 'package:farmatime/data/repositories/clock_repository_impl.dart';
import 'package:farmatime/domain/usecases/clock/update_entry_usecase.dart';



class EditEntryBinding extends Bindings {
  @override
  void dependencies() {
    // Repo
    Get.lazyPut<ClockRepository>(() => ClockRepositoryImpl(), fenix: true);

    // Usecase
    Get.lazyPut<UpdateEntryUseCase>(
      () => UpdateEntryUseCase(Get.find<ClockRepository>()),
      fenix: true,
    );
  }
}