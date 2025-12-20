import 'dart:async';

import 'package:farmatime/domain/usecases/stripe/create_billing_portal_session_usecase.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/billing/billing_models.dart';
import 'package:farmatime/domain/usecases/stripe/list_invoices_usecase.dart';
import 'package:farmatime/domain/usecases/stripe/create_stripe_customer_usecase.dart';
import 'package:url_launcher/url_launcher.dart';



class SubscriptionController extends GetxController {
  final ListInvoicesUseCase listInvoicesUseCase;
  final CreateStripeCustomerUseCase createStripeCustomerUseCase;
  final CreateBillingPortalSessionUseCase createBillingPortalSessionUseCase;

  SubscriptionController({
    required this.listInvoicesUseCase,
    required this.createStripeCustomerUseCase,
    required this.createBillingPortalSessionUseCase,
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
      } else if (data['currentPeriodEnd'] is int) {
        currentPeriodEnd.value = DateTime.fromMillisecondsSinceEpoch((data['currentPeriodEnd'] as int) * 1000);
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
      final res = await createStripeCustomerUseCase.call(companyId: companyId);
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

  //abrir portal de facturación
  Future<void> openBillingPortal() async {
    if (!isCompanyAccount) {
      Get.snackbar('Permisos insuficientes',
          'Solo la cuenta de empresa puede gestionar la suscripción.');
      return;
    }

    isLoading.value = true;
    try {
      final res = await createBillingPortalSessionUseCase.call(
        companyId: companyId,
      );
      if (res.success && res.data!.isNotEmpty) {
        final url = res.data;
        final uri = Uri.parse(url!);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Get.snackbar('Error',
            'No se pudo abrir el portal de facturación. Inténtalo de nuevo.');
      }
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}