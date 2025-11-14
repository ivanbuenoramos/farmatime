import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/routes/routes.dart';
import 'package:get/get.dart';

class CompanyMainController extends GetxController {
  
  final Brain brain = Get.find<Brain>();

  final RxInt indexTab = 0.obs;

  @override
  void onInit() {
    super.onInit();
    if (brain.company.value?.verifiedEmail == false) {
      Future.microtask(() {
        Get.offNamed(Routes.companyAuthVerifyEmail, arguments: {
          'companyId': brain.company.value?.id,
          'company': brain.company.value,
        });
      });
    }
  }


}
