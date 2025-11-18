import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/billing/prepare_payment_models.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/usecases/stripe/prepare_seat_change_payment_usecase.dart';
import 'package:farmatime/presentation/pages/company/subscription/subscription_controller.dart';

class ConfirmSeatChangeController extends GetxController {
  ConfirmSeatChangeController({
    required this.prepareSeatChangePaymentUseCase,
    required this.initialSeats,
    required this.newSeats,
  });

  final PrepareSeatChangePaymentUseCase prepareSeatChangePaymentUseCase;
  final int initialSeats;
  final int newSeats;

  final Brain brain = Get.find<Brain>();

  final RxBool loading = false.obs;
  final RxString error = ''.obs;
  final Rx<PrepareSeatChangePaymentResponse?> preview =
      Rx<PrepareSeatChangePaymentResponse?>(null);

  String get companyId => brain.company.value?.id ?? '';

  bool get isCompanyAccount {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null && uid == companyId;
  }

  bool get canConfirm => preview.value != null && error.value.isEmpty;

  @override
  void onInit() {
    super.onInit();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    if (companyId.isEmpty || !isCompanyAccount) {
      error.value =
          'Solo la cuenta de empresa puede actualizar las plazas de esta suscripción.';
      return;
    }

    loading.value = true;
    error.value = '';

    try {
      final Result<PrepareSeatChangePaymentResponse?> res =
          await prepareSeatChangePaymentUseCase.call(
        companyId: companyId,
        newQuantity: newSeats,
      );

      if (!res.success || res.data == null) {
        error.value = res.errorCode ?? 'No se pudo preparar el cambio de plan';
        return;
      }

      preview.value = res.data;
    } catch (e) {
      error.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  Future<void> confirmAndPay(BuildContext context) async {
    final data = preview.value;
    if (data == null) return;

    loading.value = true;
    try {
      // Si no hay pago, solo cerramos y refrescamos
      if (data.requiresPayment == false) {
        _finishAndRefresh();
        return;
      }

      // Si hay pago, montamos PaymentSheet con los datos recibidos
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'FarmaTime',
          customerId: data.customerId,
          customerEphemeralKeySecret: data.ephemeralKeySecret,
          paymentIntentClientSecret: data.paymentIntentClientSecret,
          style: ThemeMode.system,
          allowsDelayedPaymentMethods: false,
          applePay: const PaymentSheetApplePay(merchantCountryCode: 'ES'),
          googlePay: const PaymentSheetGooglePay(
            merchantCountryCode: 'ES',
            testEnv: false,
          ),
        ),
      );

      await Stripe.instance.presentPaymentSheet();
      _finishAndRefresh();
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        Get.snackbar('Pago cancelado', 'No se ha realizado ningún cargo');
      } else {
        Get.snackbar('Error de pago', e.error.localizedMessage ?? e.toString());
      }
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      loading.value = false;
    }
  }

  void _finishAndRefresh() {
    // Cerramos SOLO esta pantalla con result:true
    Get.back(result: true);
    // Y luego cerramos el checkout de plazas
    Get.back();
    Get.snackbar('Listo', 'Tu suscripción se actualizará en segundos.');
    if (Get.isRegistered<SubscriptionController>()) {
      Get.find<SubscriptionController>().invoicesLoading.refresh();
    }
  }
}