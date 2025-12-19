import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:get/get.dart';

class EmployeeMainController extends GetxController {
  final RxInt indexTab = 0.obs;

  final Brain brain = Get.find<Brain>();

  @override
  void onReady() {
    super.onReady();
    redirectToSetPasswordIfNeeded();
  }

  void redirectToSetPasswordIfNeeded() {
    checkAccountStatus();
  }

  void checkAccountStatus() {
    if (brain.employee.value != null && brain.employee.value!.accountStatus == EmployeeAccountStatus.disabled) {
      Get.offAllNamed(Routes.employeeSubscriptionCanceled);
    } else if (brain.employee.value != null && brain.employee.value!.tempPassword != null && brain.employee.value!.tempPassword! != '') {
      Get.offNamed(Routes.employeeSetPassword);
    }
  }
}
