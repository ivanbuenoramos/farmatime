import 'package:get/get.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/domain/usecases/firebase_auth/log_out_usecase.dart';

class SubscriptionBlockedController extends GetxController {
  final LogOutUseCase logOutUseCase;
  final Brain brain = Get.find<Brain>();

  SubscriptionBlockedController({required this.logOutUseCase});

  /// Si el listener de Firestore detecta que la suscripción vuelve a estar
  /// pagada (renovación / restore exitoso), salimos automáticamente de la
  /// pantalla de bloqueo y entramos a la app.
  @override
  void onInit() {
    super.onInit();
    ever(brain.company, (company) {
      if (company == null) return;
      if (!company.isPharmacyBlocked) {
        Get.offAllNamed(Routes.companyMain);
      }
    });
  }

  Future<void> logOut() async {
    brain.clearSession();
    await logOutUseCase.call();
    Get.offAllNamed(Routes.index);
  }
}
