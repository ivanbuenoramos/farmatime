import 'dart:async';
import 'package:farmatime/core/utils/seat_cost_breakdown.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/domain/usecases/stripe/create_seat_checkout_session_usecase.dart';

// ✅ importa el helper donde lo pongas
// import 'package:farmatime/core/utils/seat_cost_estimator.dart';

class SeatCheckoutController extends GetxController {
  SeatCheckoutController({
    required this.createSeatCheckoutSessionUseCase,
  });

  final CreateSeatCheckoutSessionUseCase createSeatCheckoutSessionUseCase;
  final Brain brain = Get.find<Brain>();

  final RxInt seats = 1.obs;
  final RxBool processing = false.obs;

  final RxString currency = 'eur'.obs;

  final RxnInt nowSubtotalCents = RxnInt();
  final RxnInt nowTaxCents = RxnInt();
  final RxnInt nowTotalCents = RxnInt();

  final RxnInt nextSubtotalCents = RxnInt();
  final RxnInt nextTaxCents = RxnInt();
  final RxnInt nextTotalCents = RxnInt();

  Timer? _debounce;

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
    currency.value = 'eur';

    // ✅ recalcula cuando cambie seats
    ever<int>(seats, (_) => _scheduleEstimate());

    // ✅ recalcula cuando llegue/actualice la company desde Firestore
    ever(brain.company, (_) => _scheduleEstimate());

    // ✅ cálculo inicial
    _scheduleEstimate();
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }

  void inc() => seats.value++;
  void dec() => seats.value = seats.value <= 1 ? 1 : seats.value - 1;

  void _scheduleEstimate() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), _estimate);
  }

  void _estimate() {
    final company = brain.company.value;
    if (company == null) {
      _setAllNull();
      return;
    }

    final currentContracted = company.contractedSeats ?? 1;
    final currentSeats = currentContracted <= 0 ? 1 : currentContracted;

    // ✅ si no hay cambios: hoy 0 y next según current (o según new, tú eliges)
    if (!hasChanges) {
      nowSubtotalCents.value = 0;
      nowTaxCents.value = 0;
      nowTotalCents.value = 0;

      const unitMonthlyCents = 100;
      const taxRate = 0.21;

      final newPaid = (currentSeats - 1).clamp(0, 999999);
      final nextSub = newPaid * unitMonthlyCents;
      final nextTax = (nextSub * taxRate).round();

      nextSubtotalCents.value = nextSub;
      nextTaxCents.value = nextTax;
      nextTotalCents.value = nextSub + nextTax;
      return;
    }

    // 👇 aquí está tu caso: YA existen
    final DateTime? periodStart = company.currentPeriodStart;
    final DateTime? periodEnd = company.currentPeriodEnd;

    if (periodStart == null || periodEnd == null || !periodEnd.isAfter(periodStart)) {
      // podemos mostrar próxima mensualidad igual aunque “hoy” sea desconocido
      nowSubtotalCents.value = null;
      nowTaxCents.value = null;
      nowTotalCents.value = null;

      const unitMonthlyCents = 100;
      const taxRate = 0.21;
      final newPaid = (seats.value - 1).clamp(0, 999999);
      final nextSub = newPaid * unitMonthlyCents;
      final nextTax = (nextSub * taxRate).round();

      nextSubtotalCents.value = nextSub;
      nextTaxCents.value = nextTax;
      nextTotalCents.value = nextSub + nextTax;
      return;
    }

    const unitMonthlyCents = 100;
    const taxRate = 0.21;

    final breakdown = estimateSeatCosts(
      currentTotalSeats: currentSeats,
      //17 marzo 2026
      // now: DateTime(2026, 3, 7),
      newTotalSeats: seats.value,
      periodStart: periodStart,
      periodEnd: periodEnd,
      unitMonthlyCents: unitMonthlyCents,
      taxRate: taxRate,
    );

    nowSubtotalCents.value = breakdown.nowSubtotalCents;
    nowTaxCents.value = breakdown.nowTaxCents;
    nowTotalCents.value = breakdown.nowTotalCents;

    nextSubtotalCents.value = breakdown.nextSubtotalCents;
    nextTaxCents.value = breakdown.nextTaxCents;
    nextTotalCents.value = breakdown.nextTotalCents;
  }

  Future<void> onContinue() async {
    if (!hasChanges || processing.value) return;

    if (companyId.isEmpty) {
      Get.snackbar('Error', 'Empresa no encontrada');
      return;
    }

    processing.value = true;

    try {
      final res = await createSeatCheckoutSessionUseCase.call(
        companyId: companyId,
        newTotalSeats: seats.value,
      );

      if (!res.success || res.data == null) {
        Get.snackbar('Error', res.errorCode ?? 'No se pudo iniciar el pago');
        return;
      }

      final data = res.data!;

      if (data.noPayment == true) {
        Get.back();
        return;
      }

      final url = data.url;
      if (url == null || url.isEmpty) {
        Get.snackbar('Error', 'No se pudo abrir Checkout (URL vacía)');
        return;
      }

      final uri = Uri.tryParse(url);
      if (uri == null) {
        Get.snackbar('Error', 'URL de Checkout inválida');
        return;
      }

      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        Get.snackbar('Error', 'No se pudo abrir el navegador');
        return;
      }

      Get.back();
    } catch (e, s) {
      debugPrint('Seat checkout error: $e');
      debugPrint('$s');
      Get.snackbar('Error', 'No se pudo iniciar el pago');
    } finally {
      processing.value = false;
    }
  }

  void _setAllNull() {
    nowSubtotalCents.value = null;
    nowTaxCents.value = null;
    nowTotalCents.value = null;
    nextSubtotalCents.value = null;
    nextTaxCents.value = null;
    nextTotalCents.value = null;
  }
}