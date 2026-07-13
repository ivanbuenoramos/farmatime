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
    final emp = brain.employee.value;
    if (emp == null) return;
    if (emp.accountStatus == EmployeeAccountStatus.disabled) {
      Get.offAllNamed(Routes.employeeSubscriptionCanceled);
    } else if (emp.hasTempPassword) {
      Get.offNamed(Routes.employeeSetPassword);
    }
  }
}
