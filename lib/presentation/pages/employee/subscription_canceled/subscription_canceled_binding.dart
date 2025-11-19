import 'package:farmatime/data/repositories/firebase_auth_repository_impl.dart';
import 'package:farmatime/domain/repositories/firebase_auth_repository.dart';
import 'package:farmatime/domain/usecases/firebase_auth/log_out_usecase.dart';
import 'package:get/get.dart';

import 'package:farmatime/presentation/pages/employee/subscription_canceled/subscription_canceled_controller.dart';



class EmployeeSubscriptionCanceledBinding extends Bindings {
  @override
  void dependencies() {

    Get.lazyPut<FirebaseAuthRepository>(() => FirebaseAuthRepositoryImpl());

    Get.lazyPut<LogOutUseCase>(
      () => LogOutUseCase(Get.find<FirebaseAuthRepository>()),
    );
    
    Get.lazyPut<EmployeeSubscriptionCanceledController>(() => EmployeeSubscriptionCanceledController(
      logOutUseCase: Get.find<LogOutUseCase>(),
    ));
  }
}