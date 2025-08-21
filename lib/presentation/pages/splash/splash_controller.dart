import 'package:farmatime/domain/usecases/company/get_company_by_id_usecase.dart';
import 'package:get/get.dart';
import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/routes/routes.dart';

class SplashController extends GetxController {

  final GetCompanyByIdUseCase getCompanyByIdUseCase;

  SplashController({
    required this.getCompanyByIdUseCase,
  });

  final Brain brain = Get.find<Brain>();

  @override
  void onReady() {
    super.onReady();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(seconds: 1));
    if (brain.company.value != null) {
      await fetchCompany();
      Get.offAllNamed(Routes.companyMain);
    } else if (brain.employee.value != null) {
      Get.offAllNamed(Routes.employeeMain);
    } else {
      Get.offAllNamed(Routes.index);
    }
  }

  Future<void> fetchCompany() async {
    final result = await getCompanyByIdUseCase.call(brain.company.value!.id);
    if (result.success && result.data != null) {
      brain.company.value = result.data;
    } else {
      Get.snackbar('Error', 'No se pudo obtener la empresa');
    }
  }
}
