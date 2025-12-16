import 'package:farmatime/data/models/billing/seat_change_apply_response.dart';
import 'package:farmatime/data/models/billing/seat_change_preview_response.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/presentation/pages/company/subscription/subscription_controller.dart';

// nuevos
import 'package:farmatime/domain/usecases/stripe/preview_seat_change_usecase.dart';
import 'package:farmatime/domain/usecases/stripe/apply_seat_change_usecase.dart';

class ConfirmSeatChangeController extends GetxController {
  ConfirmSeatChangeController({
    required this.previewSeatChangeUseCase,
    required this.applySeatChangeUseCase,
    required this.initialSeats,
    required this.newSeats,
  });

  final PreviewSeatChangeUseCase previewSeatChangeUseCase;
  final ApplySeatChangeUseCase applySeatChangeUseCase;

  final int initialSeats;
  final int newSeats;

  final Brain brain = Get.find<Brain>();

  final RxBool loading = false.obs;
  final RxString error = ''.obs;

  final Rx<SeatChangePreviewResponse?> preview =
      Rx<SeatChangePreviewResponse?>(null);

  List<String> get employeesToDeactivate =>
      (Get.arguments?['employeesToDeactivate'] as List?)?.cast<String>() ?? <String>[];

  String get companyId => brain.company.value?.id ?? '';

  bool get isCompanyAccount {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null && uid == companyId;
  }

  bool get canConfirm => preview.value != null && error.value.isEmpty && !loading.value;

  @override
  void onInit() {
    super.onInit();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    if (companyId.isEmpty || !isCompanyAccount) {
      error.value = 'Solo la cuenta de empresa puede actualizar plazas.';
      return;
    }

    loading.value = true;
    error.value = '';

    try {
      final Result<SeatChangePreviewResponse?> res =
          await previewSeatChangeUseCase.call(
        companyId: companyId,
        newTotalSeats: newSeats,
      );

      if (!res.success || res.data == null) {
        error.value = res.errorCode ?? 'No se pudo cargar el resumen.';
        return;
      }

      preview.value = res.data!;
    } catch (e) {
      error.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  Future<void> confirm(BuildContext context) async {
    if (!isCompanyAccount) return;

    loading.value = true;
    error.value = '';

    try {
      // 1) aplicar (Stripe)
      final Result<SeatChangeApplyResponse?> res = await applySeatChangeUseCase.call(
        companyId: companyId,
        newTotalSeats: newSeats,
        employeesToDeactivate: employeesToDeactivate,
      );

      if (!res.success || res.data == null) {
        Get.snackbar('Error', res.errorCode ?? 'No se pudo aplicar el cambio.');
        return;
      }

      final d = res.data!;
      if (!d.ok) {
        Get.snackbar('Error', 'No se pudo aplicar el cambio.');
        return;
      }

      // 2) si requiere acción (SCA), mostrar PaymentSheet
      if (d.requiresAction) {
        if ((d.customerId ?? '').isEmpty ||
            (d.ephemeralKeySecret ?? '').isEmpty ||
            (d.paymentIntentClientSecret ?? '').isEmpty) {
          Get.snackbar('Error', 'Faltan datos para completar el pago.');
          return;
        }

        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            merchantDisplayName: 'FarmaTime',
            customerId: d.customerId!,
            customerEphemeralKeySecret: d.ephemeralKeySecret!,
            paymentIntentClientSecret: d.paymentIntentClientSecret!,
            style: ThemeMode.system,
            allowsDelayedPaymentMethods: false,
            applePay: const PaymentSheetApplePay(merchantCountryCode: 'ES'),
            googlePay: const PaymentSheetGooglePay(merchantCountryCode: 'ES'),
          ),
        );

        await Stripe.instance.presentPaymentSheet();
      }

      // 3) cerrar y refrescar
      Get.back(result: true); // cierra ConfirmSeatChangePage
      Get.back(); // cierra SeatCheckoutPage

      final p = preview.value;
      if (p != null && p.scheduledAtPeriodEnd) {
        Get.snackbar('Listo', 'La reducción se aplicará en la próxima renovación.');
      } else {
        Get.snackbar('Listo', 'Cambio aplicado. Puede tardar unos segundos en reflejarse.');
      }

      if (Get.isRegistered<SubscriptionController>()) {
        Get.find<SubscriptionController>().invoicesLoading.refresh();
      }
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        Get.snackbar('Pago cancelado', 'No se ha realizado ningún cargo.');
      } else {
        Get.snackbar('Error de pago', e.error.localizedMessage ?? e.toString());
      }
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      loading.value = false;
    }
  }
}