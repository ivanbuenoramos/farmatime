import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/domain/usecases/stripe/prepare_seat_payment_sheet_usecase.dart';

class SeatCheckoutController extends GetxController {
  SeatCheckoutController({
    required this.prepareSeatPaymentSheetUseCase,
  });

  final PrepareSeatPaymentSheetUseCase prepareSeatPaymentSheetUseCase;

  final Brain brain = Get.find<Brain>();

  final RxInt seats = 1.obs;
  final RxBool processing = false.obs;

  String get companyId => brain.company.value?.id ?? '';
  int get contractedSeatsNow => brain.company.value?.contractedSeats ?? 1;

  bool get hasChanges {
    final current = contractedSeatsNow <= 0 ? 1 : contractedSeatsNow;
    return seats.value != current;
  }

  @override
  void onInit() {
    super.onInit();
    seats.value = contractedSeatsNow <= 0 ? 1 : contractedSeatsNow;
  }

  void inc() => seats.value++;
  void dec() => seats.value = seats.value <= 1 ? 1 : seats.value - 1;

  Future<void> onContinue() async {
    if (!hasChanges || processing.value) return;
    if (companyId.isEmpty) {
      Get.snackbar('Error', 'Empresa no encontrada');
      return;
    }

    processing.value = true;

    try {
      final res = await prepareSeatPaymentSheetUseCase.call(
        companyId: companyId,
        newTotalSeats: seats.value,
      );

      if (!res.success || res.data == null) {
        Get.snackbar('Error', res.errorCode ?? 'No se pudo iniciar el pago');
        return;
      }

      final data = res.data!;

      if (data.noPayment) {
        // Downgrade o sin cobro -> el webhook subscription.updated te sincroniza Firestore
        Get.back();
        return;
      }

      final cs = data.paymentIntentClientSecret;
      final cust = data.customerId;
      final eph = data.ephemeralKey;

      if (cs == null || cust == null || eph == null) {
        Get.snackbar('Error', 'Faltan datos para PaymentSheet');
        return;
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'FarmaTime',
          paymentIntentClientSecret: cs,
          customerId: cust,
          customerEphemeralKeySecret: eph,
          allowsDelayedPaymentMethods: false,
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      // NO actualices Firestore aquí. Webhook hará el update real.
      Get.back();
    } on StripeException catch (_) {
      Get.snackbar('Pago cancelado', 'No se completó el pago');
    } catch (e, s) {
      debugPrint('Seat payment error: $e');
      debugPrint('$s');
      Get.snackbar('Error', 'No se pudo completar el pago');
    } finally {
      processing.value = false;
    }
  }
}