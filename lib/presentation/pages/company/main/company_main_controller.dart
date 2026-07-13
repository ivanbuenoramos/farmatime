import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:farmatime/data/models/company_model.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/usecases/employee/get_employees_by_company_id_usecase.dart';

import 'package:get/get.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/config.dart';
import 'package:farmatime/core/routes/routes.dart';



class CompanyMainController extends GetxController {

  final GetEmployeesByCompanyIdUseCase getEmployeesByCompanyIdUseCase;

  CompanyMainController({
    required this.getEmployeesByCompanyIdUseCase,
  });

  final Brain brain = Get.find<Brain>();

  final RxInt indexTab = 0.obs;

  /// Mostrar el banner de "fallo en el pago" cuando la suscripción está en
  /// periodo de gracia oficial del store. Solo lo ve la farmacia, los
  /// empleados no se enteran (decisión de producto).
  final RxBool showGracePeriodBanner = false.obs;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _companySub;

  @override
  void onReady() {
    super.onReady();
    // Bloqueo total: hasta que el email no esté verificado, la farmacia no puede
    // usar la app. Se la lleva a la pantalla de verificación (cuya única salida
    // sin verificar es cerrar sesión).
    if (_emailNotVerified) {
      Future.microtask(() {
        if (Get.currentRoute != Routes.companyAuthVerifyEmail) {
          Get.offAllNamed(
            Routes.companyAuthVerifyEmail,
            arguments: {'company': brain.company.value},
          );
        }
      });
      return;
    }

    _refreshGatingFromBrain();
    _listenCompanyDoc();
  }

  /// El email de la empresa no está verificado, mirando tanto el estado de Auth
  /// (fuente de verdad) como el flag denormalizado en el modelo.
  bool get _emailNotVerified {
    if (Config.skipUserContactVerification) return false;
    final authVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    final modelVerified = brain.company.value?.verifiedEmail ?? false;
    return !(authVerified || modelVerified);
  }

  @override
  void onClose() {
    _companySub?.cancel();
    super.onClose();
  }

  /// Suscribe al doc de la company en Firestore para reaccionar en tiempo
  /// real a cambios de billingStatus / canceledAt: si el backend (webhook
  /// IAP) marca la suscripción como cancelada, navegamos a la pantalla
  /// bloqueante sin esperar a que el usuario reabra la app.
  void _listenCompanyDoc() {
    final companyId = brain.company.value?.id;
    if (companyId == null || companyId.isEmpty) return;

    _companySub?.cancel();
    _companySub = FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .snapshots()
        .listen((doc) {
      final data = doc.data();
      if (data == null) return;
      // Reconstruimos el modelo para que los getters de gating reflejen el
      // estado actual (incluyendo subscription.canceledAt).
      final json = Map<String, dynamic>.from(data);
      json['id'] = doc.id;
      try {
        final updated = CompanyModel.fromJson(json);
        brain.company.value = updated;
        _refreshGatingFromBrain();
      } catch (_) {
        // Si el doc tiene un shape inesperado, ignoramos: el cliente quedará
        // con el último modelo válido conocido.
      }
    });
  }

  void _refreshGatingFromBrain() {
    final company = brain.company.value;
    if (company == null) return;

    if (company.isPharmacyBlocked) {
      showGracePeriodBanner.value = false;
      // microtask para evitar navegar mientras se está construyendo el árbol
      // tras un setState/Obx upstream.
      Future.microtask(() {
        if (Get.currentRoute != Routes.companySubscriptionBlocked) {
          Get.offAllNamed(Routes.companySubscriptionBlocked);
        }
      });
      return;
    }

    showGracePeriodBanner.value = company.isInGracePeriod;
  }

  Future<void> getEmployees() async {

    if (brain.company.value == null) return;

    final Result<List<EmployeeModel>> result = await getEmployeesByCompanyIdUseCase.call(
      companyId: brain.company.value!.id,
      includeDeleted: true
    );

    if (result.success) {
      brain.companyEmployees.assignAll(result.data);
    }
  }
}
