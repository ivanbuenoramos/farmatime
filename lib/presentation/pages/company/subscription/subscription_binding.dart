import 'package:get/get.dart';

import 'package:farmatime/data/repositories/employee_repository_impl.dart';
import 'package:farmatime/data/repositories/iap_repository_impl.dart';
import 'package:farmatime/domain/repositories/employee_repository.dart';
import 'package:farmatime/domain/repositories/iap_repository.dart';

import 'subscription_controller.dart';

class SubscriptionBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<IapRepository>(() => IapRepositoryImpl());
    if (!Get.isRegistered<EmployeeRepository>()) {
      Get.lazyPut<EmployeeRepository>(() => EmployeeRepositoryImpl());
    }
    Get.lazyPut<SubscriptionController>(
      () => SubscriptionController(
        iapRepository: Get.find<IapRepository>(),
        employeeRepository: Get.find<EmployeeRepository>(),
      ),
    );
  }
}
