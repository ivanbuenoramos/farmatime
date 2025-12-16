import 'package:farmatime/domain/usecases/stripe/update_seats_and_pay_usecase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get/get.dart';

import 'package:farmatime/core/app/brain.dart';

class SeatCheckoutController extends GetxController {
  SeatCheckoutController({
    required this.updateSeatsAndPayUseCase,
  });

  final UpdateSeatsAndPayUseCase updateSeatsAndPayUseCase;

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
    if (!hasChanges) return;

    processing.value = true;

    try {
      final res = await updateSeatsAndPayUseCase.call(
        companyId: companyId,
        newTotalSeats: seats.value,
      );

      if (!res.success) {
        print(res.errorCode);
        Get.snackbar('Error', 'No se pudo procesar el cambio');
        return;
      }

      final clientSecret = res.data?.clientSecret;

      // ⬇️ NO hay pago (bajar plazas o gratis)
      if (clientSecret == null) {
        Get.back();
        return;
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'FarmaTime',
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      Get.back(); // ✅ cerrar al pagar

    } catch (e, s) {
      debugPrint('Stripe error: $e');
      debugPrint('$s');
      Get.snackbar('Error de pago', e.toString());
    } finally {
      processing.value = false;
    }
  }
}