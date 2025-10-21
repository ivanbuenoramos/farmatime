import 'package:farmatime/data/models/billing/prepare_payment_models.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/usecases/stripe/create_stripe_customer_and_subscription_usecase.dart';
import 'package:farmatime/domain/usecases/stripe/prepare_seat_change_payment_usecase.dart';
import 'package:farmatime/presentation/pages/company/subscription/subscription_controller.dart';

enum SeatPayMethod { nativePay, card }

class SeatCheckoutController extends GetxController {
  SeatCheckoutController({
    required this.createStripeCustomerAndSubscriptionUseCase,
    required this.prepareSeatChangePaymentUseCase,
  });

  final CreateStripeCustomerAndSubscriptionUseCase
      createStripeCustomerAndSubscriptionUseCase;
  final PrepareSeatChangePaymentUseCase prepareSeatChangePaymentUseCase;

  final Brain brain = Get.find<Brain>();

  // ---- STATE ----
  final RxInt seats = 1.obs;
  final RxBool loading = false.obs;
  final Rx<SeatPayMethod> method = SeatPayMethod.nativePay.obs;
  final RxString error = ''.obs;

  // lecturas rápidas
  String get companyId => brain.company.value?.id ?? '';
  int get contractedSeatsNow => brain.company.value?.contractedSeats ?? 1;
  bool get hasStripeSetup =>
      (brain.company.value?.stripeCustomerId ?? '').isNotEmpty &&
      (brain.company.value?.stripeSubscriptionId ?? '').isNotEmpty;

  bool get isCompanyAccount {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null && uid == companyId;
  }

  // estimación visual (1ª plaza gratis, resto 1€/mes)
  int get monthlyCents => (seats.value > 1) ? (seats.value - 1) * 100 : 0;

  // bloquear CTA si no hay cambios
  bool get hasChanges => seats.value != contractedSeatsNow;

  @override
  void onInit() {
    super.onInit();
    final init = contractedSeatsNow <= 0 ? 1 : contractedSeatsNow;
    seats.value = init;
  }

  void inc() => seats.value = seats.value + 1;
  void dec() => seats.value = seats.value <= 1 ? 1 : seats.value - 1;

  Future<void> pay(BuildContext context) async {
    if (companyId.isEmpty) {
      Get.snackbar('Error', 'Empresa no encontrada');
      return;
    }
    if (!isCompanyAccount) {
      Get.snackbar('Permisos', 'Solo la cuenta de empresa puede actualizar plazas.');
      return;
    }
    if (!hasChanges) {
      Get.snackbar('Sin cambios', 'No has modificado las plazas.');
      return;
    }

    loading.value = true;
    error.value = '';

    try {
      // 1) Asegura que existe Customer + Sub (mínimo 1 plaza)
      if (!hasStripeSetup) {
        final res = await createStripeCustomerAndSubscriptionUseCase.call(
          companyId,
          initialQuantity: 1,
        );
        if (!res.success) {
          error.value = res.errorCode ?? 'No se pudo preparar la suscripción';
          Get.snackbar('Error', error.value);
          loading.value = false;
          return;
        }
      }

      final int newQty = seats.value;

      // 2) Prepara cambio: pone la sub en default_incomplete y devuelve PaymentIntent
      final Result<PrepareSeatChangePaymentResponse?> prep =
          await prepareSeatChangePaymentUseCase.call(
        companyId: companyId,
        newQuantity: newQty,
      );

      if (!prep.success || prep.data == null) {
        error.value = prep.errorCode ?? 'No se pudo iniciar el pago';
        Get.snackbar('Error', error.value);
        loading.value = false;
        return;
      }

      final payload = prep.data!;
      debugPrint('requiresPayment=${payload.requiresPayment}');

      // 3) Si no hay que pagar (p. ej. bajar plazas o total 0€), cerramos sin PaymentSheet.
      if (payload.requiresPayment == false) {
        _finishAndRefresh();
        return;
      }

      // 4) PaymentSheet (tarjetas guardadas, añadir tarjeta y Apple/Google Pay)
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'FarmaTime',
          customerId: payload.customerId,
          customerEphemeralKeySecret: payload.ephemeralKeySecret,
          paymentIntentClientSecret: payload.paymentIntentClientSecret,
          style: ThemeMode.system,
          allowsDelayedPaymentMethods: false,
          applePay: const PaymentSheetApplePay(merchantCountryCode: 'ES'),
          googlePay: const PaymentSheetGooglePay(
            merchantCountryCode: 'ES',
            testEnv: false, // true si quieres sandbox explícito
          ),
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      // 5) Éxito: el webhook actualizará Firestore (contractedSeats, estado, etc.)
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
    Get.back(); // cerrar checkout
    Get.snackbar('Listo', 'Tu suscripción se actualizará en segundos.');
    if (Get.isRegistered<SubscriptionController>()) {
      // el stream de Firestore ya actualiza, pero por si quieres forzar:
      Get.find<SubscriptionController>().invoicesLoading
          .refresh(); // pequeño “tick” visual
    }
  }
}