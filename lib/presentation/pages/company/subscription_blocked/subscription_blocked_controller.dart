import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/data/models/company_model.dart';
import 'package:farmatime/domain/usecases/firebase_auth/log_out_usecase.dart';

class SubscriptionBlockedController extends GetxController {
  final LogOutUseCase logOutUseCase;
  final Brain brain = Get.find<Brain>();

  SubscriptionBlockedController({required this.logOutUseCase});

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _companySub;

  /// Cuando la suscripción vuelve a estar pagada (renovación / restore /
  /// webhook del backend), salimos automáticamente de la pantalla de bloqueo.
  /// En esta ruta no hay ningún otro listener del doc de la empresa (el de
  /// CompanyMainController muere al salir del main), así que lo escuchamos aquí.
  @override
  void onInit() {
    super.onInit();
    ever(brain.company, (company) {
      if (company == null) return;
      if (!company.isPharmacyBlocked) {
        Get.offAllNamed(Routes.companyMain);
      }
    });
    _listenCompanyDoc();
  }

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
      try {
        final json = Map<String, dynamic>.from(data)..['id'] = doc.id;
        brain.updateCompanyData(CompanyModel.fromJson(json));
      } catch (e) {
        debugPrint('SubscriptionBlocked: doc de empresa con forma inesperada: $e');
      }
    }, onError: (e) {
      // p. ej. permission-denied al cerrar sesión desde esta pantalla.
      debugPrint('SubscriptionBlocked: stream empresa error: $e');
    });
  }

  Future<void> logOut() async {
    await _companySub?.cancel();
    _companySub = null;
    brain.clearSession();
    await logOutUseCase.call();
    Get.offAllNamed(Routes.index);
  }

  @override
  void onClose() {
    _companySub?.cancel();
    super.onClose();
  }
}
