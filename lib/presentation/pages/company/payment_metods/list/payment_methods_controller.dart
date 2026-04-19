// lib/presentation/pages/company/payment_methods/payment_methods_controller.dart
import 'package:get/get.dart';
import 'package:flutter/material.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/billing/payment_method_model.dart';
import 'package:farmatime/domain/usecases/stripe/list_payment_methods_usecase.dart';
import 'package:farmatime/domain/usecases/stripe/detach_payment_method_usecase.dart';
import 'package:farmatime/domain/usecases/stripe/set_default_payment_method_usecase.dart';

class PaymentMethodsController extends GetxController {
  final ListPaymentMethodsUseCase listPaymentMethodsUseCase;
  final SetDefaultPaymentMethodUseCase setDefaultPaymentMethodUseCase;
  final DetachPaymentMethodUseCase detachPaymentMethodUseCase;
  // final CreateSetupIntentUseCase createSetupIntentUseCase;

  PaymentMethodsController({
    required this.listPaymentMethodsUseCase,
    required this.setDefaultPaymentMethodUseCase,
    required this.detachPaymentMethodUseCase,
    // required this.createSetupIntentUseCase,
  });

  final Brain brain = Get.find<Brain>();

  final RxList<PaymentMethodModel> methods = <PaymentMethodModel>[].obs;
  final RxBool loading = false.obs;
  final RxString error = ''.obs;

  String get companyId => brain.company.value?.id ?? '';

  @override
  void onInit() {
    super.onInit();
    fetchMethods();
  }

  Future<void> fetchMethods() async {
    if (companyId.isEmpty) return;
    loading.value = true;
    error.value = '';
    final res = await listPaymentMethodsUseCase.call(companyId);
    if (res.success) {
      methods.assignAll(res.data);
    } else {
      error.value = res.errorCode ?? 'No se pudieron cargar los métodos de pago';
      Get.snackbar('Error', error.value);
    }
    loading.value = false;
  }

  Future<void> makeDefault(PaymentMethodModel pm) async {
    if (companyId.isEmpty) return;
    loading.value = true;
    final res = await setDefaultPaymentMethodUseCase.call(companyId, pm.id);
    loading.value = false;
    if (!res.success) {
      Get.snackbar('Error', res.errorCode ?? 'No se pudo establecer como predeterminada');
      return;
    }
    await fetchMethods();
  }

  Future<void> remove(PaymentMethodModel pm) async {
    if (companyId.isEmpty) return;
    loading.value = true;
    final res = await detachPaymentMethodUseCase.call(companyId, pm.id);
    loading.value = false;
    if (!res.success) {
      Get.snackbar('Error', res.errorCode ?? 'No se pudo eliminar la tarjeta');
      return;
    }
    await fetchMethods();
  }

  /// Añadir una nueva tarjeta usando PaymentSheet (SetupIntent)
  Future<void> addCard(BuildContext context) async {
    // if (companyId.isEmpty) return;
    // loading.value = true;

    // try {
    //   final res = await createSetupIntentUseCase.call(companyId);
    //   if (!res.success || res.data == null) {
    //     loading.value = false;
    //     Get.snackbar('Error', res.errorCode ?? 'No se pudo iniciar alta de tarjeta');
    //     return;
    //   }

    //   final payload = res.data!;

    //   await Stripe.instance.initPaymentSheet(
    //     paymentSheetParameters: SetupPaymentSheetParameters(
    //       merchantDisplayName: 'FarmaTime',
    //       customerId: payload.customerId,
    //       customerEphemeralKeySecret: payload.ephemeralKeySecret,
    //       setupIntentClientSecret: payload.setupIntentClientSecret,
    //       style: ThemeMode.system,
    //       allowsDelayedPaymentMethods: false,
    //       applePay: const PaymentSheetApplePay(merchantCountryCode: 'ES'),
    //       googlePay: const PaymentSheetGooglePay(
    //         merchantCountryCode: 'ES',
    //         testEnv: false,
    //       ),
    //     ),
    //   );

    //   await Stripe.instance.presentPaymentSheet(); // guarda la tarjeta

    //   Get.snackbar('Listo', 'Tarjeta añadida correctamente');
    //   await fetchMethods();
    // } on StripeException catch (e) {
    //   if (e.error.code == FailureCode.Canceled) {
    //     Get.snackbar('Cancelado', 'No se ha añadido ninguna tarjeta');
    //   } else {
    //     Get.snackbar('Error', e.error.localizedMessage ?? 'Error de Stripe');
    //   }
    // } catch (e) {
    //   print(e);
    //   Get.snackbar('Error', e.toString());
    // } finally {
    //   loading.value = false;
    // }
  }

  IconData iconForBrand(String brand) {
    switch (brand.toLowerCase()) {
      case 'visa':
        return Icons.credit_card;
      case 'mastercard':
        return Icons.credit_card;
      case 'amex':
      case 'american express':
        return Icons.credit_card;
      case 'discover':
        return Icons.credit_card;
      default:
        return Icons.credit_card;
    }
  }
}