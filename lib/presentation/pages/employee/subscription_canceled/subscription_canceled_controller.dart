import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/domain/usecases/firebase_auth/log_out_usecase.dart';
import 'package:get/get.dart';

class EmployeeSubscriptionCanceledController extends GetxController {

  final LogOutUseCase logOutUseCase;

  EmployeeSubscriptionCanceledController({
    required this.logOutUseCase,
  });

  final Brain brain = Get.find<Brain>();

  void logOut() async {
    brain.clearSession();
    await logOutUseCase.call();
    Get.offAllNamed(Routes.index);
  }

}