import 'dart:async';

import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/billing/billing_models.dart';
import 'package:farmatime/domain/usecases/stripe/list_invoices_usecase.dart';
import 'package:farmatime/domain/usecases/stripe/prepare_seat_change_payment_usecase.dart';
import 'package:farmatime/domain/usecases/stripe/update_subscription_quantity_usecase.dart';
import 'package:farmatime/domain/usecases/stripe/create_billing_portal_session_usecase.dart';
import 'package:farmatime/domain/usecases/stripe/create_stripe_customer_and_subscription_usecase.dart';



class SubscriptionController extends GetxController {
  final UpdateSubscriptionQuantityUseCase updateSubscriptionQuantityUseCase;
  final CreateBillingPortalSessionUseCase createBillingPortalSessionUseCase;
  final CreateStripeCustomerAndSubscriptionUseCase createStripeCustomerAndSubscriptionUseCase;
  final ListInvoicesUseCase listInvoicesUseCase;
  final PrepareSeatChangePaymentUseCase prepareSeatChangePaymentUseCase;

  SubscriptionController({
    required this.updateSubscriptionQuantityUseCase,
    required this.createBillingPortalSessionUseCase,
    required this.createStripeCustomerAndSubscriptionUseCase,
    required this.listInvoicesUseCase,
    required this.prepareSeatChangePaymentUseCase,
  });

  final Brain brain = Get.find<Brain>();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // Estado
  final RxString stripeCustomerId = ''.obs;
  final RxString stripeSubscriptionId = ''.obs;
  final RxInt contractedSeats = 0.obs; // plazas contratadas (quantity en Stripe)
  final RxString billingStatus = ''.obs; // active, trialing, incomplete, past_due...
  final Rx<DateTime?> currentPeriodEnd = Rx<DateTime?>(null);
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;
  final RxString prorationBehavior = 'create_prorations'.obs; // o 'none'


  final RxList<InvoiceModel> invoices = <InvoiceModel>[].obs;
  final RxBool invoicesLoading = false.obs;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  String get companyId => brain.company.value?.id ?? '';

  bool get hasStripeSetup =>
      stripeCustomerId.value.isNotEmpty &&
      stripeSubscriptionId.value.isNotEmpty;

  bool get isCompanyAccount {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null && uid == companyId;
  }

  @override
  void onInit() {
    super.onInit();
    _listenCompany();
    _loadInvoices();
  }

  void _listenCompany() {
    final id = companyId;
    if (id.isEmpty) return;

    _sub = firestore.collection('companies').doc(id).snapshots().listen((doc) {
      if (!doc.exists) return;
      final data = doc.data()!;

      // 🔹 Stripe mirror
      stripeCustomerId.value = (data['stripeCustomerId'] ?? '').toString();
      stripeSubscriptionId.value = (data['stripeSubscriptionId'] ?? '').toString();

      contractedSeats.value = (data['contractedSeats'] ?? 0) is int
          ? data['contractedSeats']
          : int.tryParse('${data['contractedSeats'] ?? 0}') ?? 0;

      billingStatus.value = (data['billingStatus'] ?? '').toString();

      if (data['currentPeriodEnd'] is Timestamp) {
        currentPeriodEnd.value = (data['currentPeriodEnd'] as Timestamp).toDate();
      } else {
        currentPeriodEnd.value = null;
      }

      // opcional: refrescar brain.company (incluye los nuevos campos)
      final cpy = brain.company.value?.copyWith(
        stripeCustomerId: stripeCustomerId.value,
        stripeSubscriptionId: stripeSubscriptionId.value,
        contractedSeats: contractedSeats.value,
        billingStatus: billingStatus.value,
        currentPeriodEnd: currentPeriodEnd.value,
      );
      if (cpy != null) brain.company.value = cpy;
    }, onError: (e) => error.value = e.toString());
  }

  // -------------------------------------------------------
  // 🔹 Debug para verificar qué UID y companyId se envían
  // -------------------------------------------------------
  void _debugAuthVsCompany() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    await FirebaseAuth.instance.currentUser?.getIdToken(true); // refresca token
    print('DEBUG billing → uid=$uid  companyId=$companyId');
  }

  // -------------------------------------------------------
  // 🔹 Actualizar número de plazas (empleados contratados)
  // -------------------------------------------------------
  // Future<void> increment() => _setQuantity(contractedSeats.value + 1);

  // Future<void> decrement() {
  //   final q = contractedSeats.value - 1;
  //   final next = q <= 0 ? 1 : q; // mínimo 1 para encajar con tu precio escalonado
  //   return _setQuantity(next);
  // }

  // Future<void> _setQuantity(int newQty) async {
  //   if (companyId.isEmpty) return;
  //   if (!isCompanyAccount) {
  //     Get.snackbar('Permisos', 'Solo la cuenta de empresa puede gestionar la suscripción');
  //     return;
  //   }

  //   isLoading.value = true;
  //   try {
  //     final res = await prepareSeatChangePaymentUseCase.call(
  //       companyId: companyId,
  //       quantity: newQty,
  //       prorationBehavior: _parseProrationBehavior(prorationBehavior.value),
  //     );

  //     if (!res.success || res.data == null) {
  //       final code = res.errorCode ?? 'Error preparando el pago';
  //       // Si backend devuelve no-payment-method, puedes abrir portal en su lugar
  //       if (code.contains('no-payment-method')) {
  //         Get.defaultDialog(
  //           title: 'Método de pago requerido',
  //           middleText: 'Añade una tarjeta para completar la compra.',
  //           textConfirm: 'Abrir portal',
  //           onConfirm: () { Get.back(); openBillingPortal(); },
  //           textCancel: 'Cancelar',
  //         );
  //       } else {
  //         Get.snackbar('Error', code);
  //       }
  //       return;
  //     }

  //     final p = res.data!;
  //     // 1) Inicializa PaymentSheet
  //     await Stripe.instance.initPaymentSheet(
  //       paymentSheetParameters: SetupPaymentSheetParameters(
  //         merchantDisplayName: 'FarmaTime',
  //         customerId: p.customerId,
  //         customerEphemeralKeySecret: p.ephemeralKeySecret,
  //         paymentIntentClientSecret: p.paymentIntentClientSecret,
  //         style: ThemeMode.system,
  //         allowsDelayedPaymentMethods: true,
  //       ),
  //     );

  //     // 2) Presenta PaymentSheet
  //     await Stripe.instance.presentPaymentSheet();

  //     // Si llega aquí, el pago se confirmó.
  //     // El webhook actualizará contractedSeats; aquí puedes dar feedback y volver atrás:
  //     Get.snackbar('Pago confirmado', 'Tus plazas se aplicarán en segundos.');
  //     // Opcional: espera un poco a que llegue el webhook
  //     await Future.delayed(const Duration(seconds: 2));
  //     Get.back(); // volver a la pantalla anterior
  //   } on StripeException catch (e) {
  //     // Cancelado o error de Stripe
  //     if (e.error.code == FailureCode.Canceled) {
  //       Get.snackbar('Pago cancelado', 'No se aplicaron cambios.');
  //     } else {
  //       Get.snackbar('Error de pago', e.error.localizedMessage ?? e.toString());
  //     }
  //   } catch (e) {
  //     Get.snackbar('Error', e.toString());
  //   } finally {
  //     isLoading.value = false;
  //   }
  // }

  // -------------------------------------------------------
  // 🔹 Portal de facturación de Stripe
  // -------------------------------------------------------
  Future<void> openBillingPortal() async {
    if (companyId.isEmpty) return;
    _debugAuthVsCompany();

    if (!isCompanyAccount) {
      Get.snackbar('Permisos insuficientes',
          'Solo la cuenta de empresa puede gestionar la facturación.');
      return;
    }

    isLoading.value = true;
    try {
      final Result<String?> res =
          await createBillingPortalSessionUseCase.call(
        companyId,
        returnUrl: null, // o tu URL de retorno si tienes una web
      );

      if (!res.success || res.data == null || res.data!.isEmpty) {
        Get.snackbar('Error', 'No se pudo abrir el portal de facturación');
        return;
      }

      final url = Uri.parse(res.data!);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        Get.snackbar('Error', 'No se pudo abrir el navegador');
      }
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  // -------------------------------------------------------
  // 🔹 Asegurar configuración Stripe (Customer + Subscription)
  // -------------------------------------------------------
  Future<void> ensureStripeSetup() async {
    if (companyId.isEmpty) return;

    if (hasStripeSetup) {
      Get.snackbar('Listo', 'La facturación ya está configurada.');
      return;
    }

    isLoading.value = true;
    try {
      final res = await createStripeCustomerAndSubscriptionUseCase.call(
        companyId,
        initialQuantity: contractedSeats.value > 0 ? contractedSeats.value : 1,
      );
      if (!res.success) {
        Get.snackbar('Atención',
            'No se pudo completar la configuración de Stripe. Inténtalo de nuevo.');
      }
    } finally {
      isLoading.value = false;
    }
  }

  // -------------------------------------------------------
  // 🔹 Conversión de prorationBehavior
  // -------------------------------------------------------
  Future<void> _loadInvoices() async {
    if (companyId.isEmpty) return;
    print('INVOICES DEBUG -> uid=${FirebaseAuth.instance.currentUser?.uid}  companyId=${brain.company.value?.id}');
    invoicesLoading.value = true;
    final res = await listInvoicesUseCase.call(companyId, limit: 50);
    print(res.success);
    if (res.success) {
      invoices.assignAll(res.data);
      print(invoices.length);
    } else {
      // opcional: Get.snackbar('Error', res.errorCode ?? 'Error al cargar facturas');
    }
    invoicesLoading.value = false;
  }

  void redirectToSeatCheckout() {
    if (!isCompanyAccount) {
      Get.snackbar('Permisos insuficientes',
          'Solo la cuenta de empresa puede gestionar la suscripción.');
      return;
    }
    Get.toNamed('/company/subscription/seat-checkout');
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}