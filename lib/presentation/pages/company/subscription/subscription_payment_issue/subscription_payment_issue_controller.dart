import 'package:farmatime/domain/usecases/stripe/get_open_invoice_payment_usecase.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/billing/setup_card_payload.dart';
import 'package:farmatime/domain/usecases/stripe/create_setup_intent_usecase.dart';



class SubscriptionPaymentIssueController extends GetxController {
  SubscriptionPaymentIssueController({
    required this.setupIntentUseCase,
    required this.getOpenInvoicePaymentUseCase,
  });

  final CreateSetupIntentUseCase setupIntentUseCase;
  final GetOpenInvoicePaymentUseCase getOpenInvoicePaymentUseCase;

  final Brain brain = Get.find<Brain>();

  final RxBool loading = false.obs;
  final RxString error = ''.obs;

  String get companyId => brain.company.value?.id ?? '';

  // @override
  // void onInit() {
  //   super.onInit();
  // }

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
    if (companyId.isEmpty) {
      Get.snackbar('Error', 'Empresa no encontrada');
      return;
    }

    loading.value = true;
    error.value = '';

    try {
      // ✅ Usar usecase (nuevo flujo)
      final res = await getOpenInvoicePaymentUseCase.call(companyId: companyId);

      if (!res.success || res.data == null) {
        final msg = res.errorCode ?? 'No se pudo cargar el pago pendiente';
        error.value = msg;
        Get.snackbar('Error', msg);
        return;
      }

      final d = res.data!;

      if (!d.hasOpenInvoice) {
        Get.snackbar('Todo correcto', 'No hay pagos pendientes.');
        return;
      }

      // Si hay invoice pero no PI (raro) -> Billing Portal
      if (d.requiresPayment != true ||
          (d.customerId ?? '').isEmpty ||
          (d.ephemeralKeySecret ?? '').isEmpty ||
          (d.paymentIntentClientSecret ?? '').isEmpty) {
        Get.snackbar('Acción requerida', 'Completa el pago desde facturación.');

        // ✅ Ideal: abrir Stripe Billing Portal
        // final portal = await stripeRepository.createBillingPortalSession(companyId, returnUrl: ...);
        // if (portal.success) launchUrlString(portal.data);
        // else Get.snackbar('Error', portal.errorCode ?? 'No se pudo abrir facturación');

        return;
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'FarmaTime',
          customerId: d.customerId!,
          customerEphemeralKeySecret: d.ephemeralKeySecret!,
          paymentIntentClientSecret: d.paymentIntentClientSecret!,
          style: ThemeMode.system,
          applePay: const PaymentSheetApplePay(merchantCountryCode: 'ES'),
          googlePay: const PaymentSheetGooglePay(merchantCountryCode: 'ES'),
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      // OJO: la confirmación real la hará el webhook (invoice.paid/subscription.active)
      Get.back();
      Get.snackbar('Pago completado', 'Pago recibido. En segundos quedará activo.');
    } on StripeException catch (e) {
      // Cancelado por el usuario -> no es error
      if (e.error.code == FailureCode.Canceled) return;

      Get.snackbar('Error de pago', e.error.localizedMessage ?? e.toString());
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      loading.value = false;
    }
  }
}