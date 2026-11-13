import 'package:farmatime/domain/usecases/company/get_company_by_id_usecase.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/core/services/toast_service.dart';

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
    // Sesión local huérfana (p. ej. cierre de sesión que no limpió el estado):
    // sin usuario de Firebase no se puede entrar a la app.
    if (FirebaseAuth.instance.currentUser == null &&
        (brain.company.value != null || brain.employee.value != null)) {
      brain.clearSession();
    }
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
    try {
      final result = await getCompanyByIdUseCase.call(brain.company.value!.id);
      if (result.success && result.data != null) {
        brain.company.value = result.data;
      } else {
        ToastService().show(title: 'Error', message: 'No se pudo obtener la empresa', type: ToastType.error);
      }
    } catch (_) {
      ToastService().show(title: 'Error', message: 'No se pudo obtener la empresa', type: ToastType.error);
    }
  }
}
