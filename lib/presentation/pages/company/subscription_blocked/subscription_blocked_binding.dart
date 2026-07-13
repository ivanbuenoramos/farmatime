import 'package:get/get.dart';

import 'package:farmatime/data/repositories/employee_repository_impl.dart';
import 'package:farmatime/data/repositories/firebase_auth_repository_impl.dart';
import 'package:farmatime/data/repositories/iap_repository_impl.dart';
import 'package:farmatime/domain/repositories/employee_repository.dart';
import 'package:farmatime/domain/repositories/firebase_auth_repository.dart';
import 'package:farmatime/domain/repositories/iap_repository.dart';
import 'package:farmatime/domain/usecases/firebase_auth/log_out_usecase.dart';
import 'package:farmatime/presentation/pages/company/subscription/subscription_controller.dart';

import 'subscription_blocked_controller.dart';

class SubscriptionBlockedBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FirebaseAuthRepository>(() => FirebaseAuthRepositoryImpl(), fenix: true);
    Get.lazyPut<LogOutUseCase>(
      () => LogOutUseCase(Get.find<FirebaseAuthRepository>()),
      fenix: true,
    );
    Get.lazyPut<IapRepository>(() => IapRepositoryImpl(), fenix: true);
    if (!Get.isRegistered<EmployeeRepository>()) {
      Get.lazyPut<EmployeeRepository>(() => EmployeeRepositoryImpl(), fenix: true);
    }
    Get.lazyPut<SubscriptionController>(
      () => SubscriptionController(
        iapRepository: Get.find<IapRepository>(),
        employeeRepository: Get.find<EmployeeRepository>(),
      ),
      fenix: true,
    );
    Get.lazyPut<SubscriptionBlockedController>(
      () => SubscriptionBlockedController(
        logOutUseCase: Get.find<LogOutUseCase>(),
      ),
    );
  }
}
