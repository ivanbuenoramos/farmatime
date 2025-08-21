import 'package:get/get.dart';

import 'package:farmatime/core/routes/routes.dart';



class IndexController extends GetxController {
  void goToLogin() {
    Get.toNamed(Routes.employeeAuthSignIn);
  }

  void goToPharmacyAccess() {
    Get.toNamed(Routes.companyAuthSignIn);
  }
}
