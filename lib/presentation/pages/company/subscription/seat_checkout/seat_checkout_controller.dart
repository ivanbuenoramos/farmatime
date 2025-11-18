import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/domain/usecases/stripe/prepare_seat_change_payment_usecase.dart';
import 'package:farmatime/presentation/pages/company/subscription/confirm_seat_change/confirm_seat_change_page.dart';
import 'package:farmatime/presentation/pages/company/subscription/confirm_seat_change/confirm_seat_change_binding.dart';



enum SeatPayMethod { nativePay, card }

class SeatCheckoutController extends GetxController {
  SeatCheckoutController({
    required this.prepareSeatChangePaymentUseCase,
  });

  final PrepareSeatChangePaymentUseCase prepareSeatChangePaymentUseCase;
  final Brain brain = Get.find<Brain>();

  final RxInt seats = 1.obs;
  final RxBool loading = false.obs;
  // final Rx<SeatPayMethod> method = SeatPayMethod.nativePay.obs;
  final RxString error = ''.obs;

  String get companyId => brain.company.value?.id ?? '';
  int get contractedSeatsNow => brain.company.value?.contractedSeats ?? 1;

  bool get hasStripeSetup =>
      (brain.company.value?.stripeCustomerId ?? '').isNotEmpty &&
      (brain.company.value?.stripeSubscriptionId ?? '').isNotEmpty;

  bool get isCompanyAccount {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null && uid == companyId;
  }

  /// 1ª plaza gratis, resto 1€/mes
  int get monthlyCents => (seats.value > 1) ? (seats.value - 1) * 100 : 0;

  bool get hasChanges {
    final current = contractedSeatsNow <= 0 ? 1 : contractedSeatsNow;
    return seats.value != current;
  }

  @override
  void onInit() {
    super.onInit();
    final init = contractedSeatsNow <= 0 ? 1 : contractedSeatsNow;
    seats.value = init;
  }

  void inc() => seats.value = seats.value + 1;
  void dec() => seats.value = seats.value <= 1 ? 1 : seats.value - 1;

  Future<void> onContinue(BuildContext context) async {
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

    final current = contractedSeatsNow <= 0 ? 1 : contractedSeatsNow;
    final newSeats = seats.value;

    // CASO A: NO hay suscripción Stripe -> flujo de alta inicial (tu otra pantalla)
    if (!hasStripeSetup) {
      Get.toNamed(
        '/subscription/checkout',
        arguments: {
          'initialSeats': newSeats,
        },
      );
      return;
    }

    // CASO B: Ya hay suscripción -> pantalla de confirmación
    final result = await Get.to<bool>(
      () => ConfirmSeatChangePage(
        initialSeats: current,
        newSeats: newSeats,
      ),
      binding: ConfirmSeatChangeBinding(
        prepareSeatChangePaymentUseCase: prepareSeatChangePaymentUseCase,
      ),
      arguments: {
        'initialSeats': current,
        'newSeats': newSeats,
      },
    );

    // ⬇️ SI EL USUARIO NO CONFIRMA, VOLVEMOS AL PLAN REAL
    if (result != true) {
      final realSeats = contractedSeatsNow <= 0 ? 1 : contractedSeatsNow;
      seats.value = realSeats;
    }
  }
}