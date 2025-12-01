import 'package:farmatime/data/models/billing/stripe_incomplete_payment_model.dart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/usecases/stripe/get_incomplete_payment_usecase.dart';

class IncompletePaymentController extends GetxController {
  final Brain brain = Get.find<Brain>();
  final GetIncompletePaymentUseCase getIncompletePaymentUseCase;

  IncompletePaymentController({
    required this.getIncompletePaymentUseCase,
  });

  final RxBool isLoading = false.obs;
  final RxnString errorText = RxnString();
  final Rxn<StripeIncompletePaymentModel> paymentInfo =
      Rxn<StripeIncompletePaymentModel>();

  String get companyId => brain.company.value!.id;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  // ───────────────────────────────────────────────
  // Cargar datos del PaymentIntent incompleto
  // ───────────────────────────────────────────────
  Future<void> load() async {
    isLoading.value = true;
    errorText.value = null;

    try {
      final Result<StripeIncompletePaymentModel?> result =
          await getIncompletePaymentUseCase(companyId);

      print('[IncompletePaymentController] result.success = ${result.success}');
      print('[IncompletePaymentController] result.data = ${result.data}');

      if (!result.success) {
        errorText.value = result.data?.toString() ?? 'Error al cargar el pago';
        return;
      }

      final StripeIncompletePaymentModel? model = result.data;

      // Si no hay modelo o no hay pago incompleto → salir
      if (model == null || !model.hasIncomplete) {
        Get.back(result: 'no_incomplete');
        return;
      }

      paymentInfo.value = model;
    } catch (e) {
      errorText.value = 'Error cargando el pago pendiente: $e';
    } finally {
      isLoading.value = false;
    }
  }

  // ───────────────────────────────────────────────
  // Mostrar importe formateado
  // ───────────────────────────────────────────────
  String getAmountLabel() {
    final info = paymentInfo.value;
    if (info == null) return '';
    final amount = info.amount.toStringAsFixed(2);
    final currency = (info.currency ?? 'eur').toUpperCase();
    return '$amount $currency';
  }

  // ───────────────────────────────────────────────
  // Reintentar pago usando Stripe PaymentSheet
  // ───────────────────────────────────────────────
  Future<void> retryPayment() async {
    print('[IncompletePaymentController] retryPayment()');

    // Si todavía no tenemos info, intenta recargar una vez
    if (paymentInfo.value == null) {
      print('[IncompletePaymentController] paymentInfo == null, recargando...');
      await load();
    }

    final info = paymentInfo.value;
    if (info == null) {
      errorText.value =
          'No se ha encontrado ningún pago pendiente. Si crees que es un error, cierra y vuelve a entrar en esta pantalla.';
      return;
    }

    isLoading.value = true;
    errorText.value = null;

    try {
      print('[IncompletePaymentController] initPaymentSheet');
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'Farmatime',
          customerId: info.customerId,
          customerEphemeralKeySecret: info.ephemeralKeySecret,
          paymentIntentClientSecret: info.paymentIntentClientSecret,
          style: ThemeMode.system,
        ),
      );

      print('[IncompletePaymentController] presentPaymentSheet');
      await Stripe.instance.presentPaymentSheet();

      // 🔥 Marcar la empresa como activa en el Brain
      final currentCompany = brain.company.value;
      if (currentCompany != null) {
        brain.company.value =
            currentCompany.copyWith(billingStatus: 'active');
      }

      Get.snackbar(
        'Pago completado',
        'Estamos actualizando tu suscripción...',
        snackPosition: SnackPosition.BOTTOM,
      );

      // Cerrar pantalla notificando éxito
      Get.back(result: 'paid');
    } on StripeException catch (e) {
      print('[IncompletePaymentController] StripeException: ${e.error.code}');
      if (e.error.code == FailureCode.Canceled) {
        errorText.value =
            'Pago cancelado. Puedes reintentarlo cuando quieras.';
      } else {
        errorText.value =
            'Error procesando el pago. Revisa tu tarjeta o inténtalo de nuevo.';
      }
    } catch (e) {
      print('[IncompletePaymentController] Error inesperado: $e');
      errorText.value = 'Error inesperado: $e';
    } finally {
      isLoading.value = false;
    }
  }
}