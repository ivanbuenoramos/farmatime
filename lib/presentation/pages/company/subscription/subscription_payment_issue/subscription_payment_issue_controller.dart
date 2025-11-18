import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/billing/setup_card_payload.dart';
import 'package:farmatime/domain/usecases/stripe/create_setup_intent_usecase.dart';
import 'package:farmatime/domain/usecases/stripe/prepare_seat_change_payment_usecase.dart';



class SubscriptionPaymentIssueController extends GetxController {
  SubscriptionPaymentIssueController({
    required this.setupIntentUseCase,
    required this.prepareSeatChangePaymentUseCase,
  });

  final CreateSetupIntentUseCase setupIntentUseCase;
  final PrepareSeatChangePaymentUseCase prepareSeatChangePaymentUseCase;

  final Brain brain = Get.find<Brain>();

  final RxBool loading = false.obs;
  final RxString error = ''.obs;

  String get companyId => brain.company.value?.id ?? '';

  @override
  void onInit() {
    super.onInit();
  }

  /// Añadir nueva tarjeta (SetupIntent)
  Future<void> addPaymentMethod(BuildContext context) async {
    loading.value = true;
    error.value = '';

    try {
      final res = await setupIntentUseCase.call(companyId);
      if (!res.success || res.data == null) {
        error.value = res.errorCode ?? 'No se pudo iniciar la vinculación de tarjeta';
        return;
      }

      final SetupCardPayload payload = res.data!;

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'FarmaTime',
          customerId: payload.customerId,
          customerEphemeralKeySecret: payload.ephemeralKeySecret,
          setupIntentClientSecret: payload.setupIntentClientSecret,
          applePay: const PaymentSheetApplePay(merchantCountryCode: 'ES'),
          googlePay: const PaymentSheetGooglePay(
            merchantCountryCode: 'ES',
            testEnv: false,
          ),
          style: ThemeMode.system,
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      Get.snackbar('Tarjeta añadida', 'Tu método de pago se ha actualizado.');
    } on StripeException catch (e) {
      if (e.error.code != FailureCode.Canceled) {
        Get.snackbar('Error de tarjeta', e.error.localizedMessage ?? e.toString());
      }
    } finally {
      loading.value = false;
    }
  }

  /// Reintentar el pago del último invoice fallado
  Future<void> retryLastInvoicePayment(BuildContext context) async {
    loading.value = true;
    error.value = '';

    try {
      // Usamos el mismo flujo que para seatChange: Stripe siempre crea PaymentIntent
      final res = await prepareSeatChangePaymentUseCase.call(
        companyId: companyId,
        newQuantity: brain.company.value!.contractedSeats!,
      );

      if (!res.success || res.data == null) {
        error.value = 'No se pudo cargar el pago pendiente';
        return;
      }

      final d = res.data!;
      if (d.requiresPayment == false) {
        Get.snackbar('Todo correcto', 'El pago ya está resuelto.');
        return;
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'FarmaTime',
          customerId: d.customerId,
          customerEphemeralKeySecret: d.ephemeralKeySecret,
          paymentIntentClientSecret: d.paymentIntentClientSecret,
          style: ThemeMode.system,
          applePay: const PaymentSheetApplePay(merchantCountryCode: 'ES'),
          googlePay: const PaymentSheetGooglePay(merchantCountryCode: 'ES'),
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      Get.back();
      Get.snackbar('Pago completado', 'Tu suscripción volverá a estar activa.');
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      loading.value = false;
    }
  }
}