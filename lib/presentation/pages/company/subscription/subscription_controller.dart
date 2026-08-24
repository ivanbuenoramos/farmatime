import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/iap/iap_plans.dart';
import 'package:farmatime/core/services/toast_service.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/data/services/iap_service.dart';
import 'package:farmatime/domain/repositories/employee_repository.dart';
import 'package:farmatime/domain/repositories/iap_repository.dart';

class SubscriptionController extends GetxController {
  final IapRepository iapRepository;
  final EmployeeRepository employeeRepository;
  final Brain brain = Get.find<Brain>();

  SubscriptionController({
    required this.iapRepository,
    required this.employeeRepository,
  });

  final RxBool isLoading = true.obs;
  final RxBool isBuying = false.obs;
  final RxList<ProductDetails> products = <ProductDetails>[].obs;
  final RxString loadDiagnostic = ''.obs;
  final RxBool storeAvailable = true.obs;

  final RxString currentProductId = ''.obs;
  final RxString billingStatus = 'none'.obs;
  final RxInt contractedSeats = 1.obs;
  final Rx<DateTime?> expiresAt = Rx<DateTime?>(null);
  final RxBool autoRenewing = false.obs;

  /// Tienda en la que se contrató la suscripción ('ios' | 'android' | '').
  /// La escribe el backend al verificar la compra y es la ÚNICA fuente fiable:
  /// una farmacia puede pagar en un iPhone y abrir luego la app en Android.
  final RxString subscriptionPlatform = ''.obs;

  final RxList<EmployeeModel> employees = <EmployeeModel>[].obs;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _companySub;
  StreamSubscription<PurchaseResult>? _purchaseSub;
  StreamSubscription<List<EmployeeModel>>? _employeesSub;

  /// True solo mientras esperamos el resultado de una compra que el USUARIO
  /// inició (pulsó Cambiar/Suscribirse/Restaurar). Sirve para NO mostrar toasts
  /// por las transacciones que StoreKit re-entrega solas al abrir la pantalla
  /// (backlog pendiente, renovaciones sandbox, etc.).
  bool _awaitingUserPurchase = false;

  /// Baja [_awaitingUserPurchase] si un "Restaurar" no produce NINGÚN evento
  /// en el purchaseStream (no había nada que restaurar): sin esto la bandera
  /// quedaría alzada y una transacción de backlog posterior mostraría toasts
  /// como si fuera respuesta a la acción del usuario.
  Timer? _restoreFlagTimer;

  /// Empleados que el usuario eligió desactivar en un downgrade. Se aplican
  /// SOLO cuando la compra se confirma (success); si cancela o falla, se
  /// descartan y nadie queda desactivado sin haber bajado de plan.
  List<String> _pendingDisableUids = const [];

  String get _companyId => brain.company.value?.id ?? '';

  /// Empleados que ocupan plaza (active + inactive). Excluye pending y deleted.
  List<EmployeeModel> get billableEmployees => employees
      .where((e) =>
          e.accountStatus == EmployeeAccountStatus.active ||
          e.accountStatus == EmployeeAccountStatus.inactive ||
          e.accountStatus == EmployeeAccountStatus.disabled)
      .toList();

  int get billableEmployeeCount => billableEmployees.length;

  /// Tienda de ESTE dispositivo.
  String get _devicePlatform => Platform.isIOS ? 'ios' : 'android';

  /// Estados en los que la suscripción sigue VIVA en la tienda, aunque el
  /// cobro esté fallando. Mientras lo esté, comprar en la otra tienda no
  /// reemplaza nada: crea una segunda suscripción en paralelo y la farmacia
  /// acaba pagando a Apple y a Google a la vez.
  static const Set<String> _liveStoreStatuses = {
    'active',
    'in_grace_period',
    'in_billing_retry',
    'on_hold',
    'paused',
  };

  /// La suscripción viva se contrató en una tienda distinta a la de este
  /// dispositivo (pagaron en un iPhone y abren la app en Android, o al revés).
  bool get isManagedByOtherStore {
    final p = subscriptionPlatform.value;
    if (p.isEmpty || p == _devicePlatform) return false;
    return _liveStoreStatuses.contains(billingStatus.value);
  }

  /// Nombre de la tienda donde vive la suscripción.
  String get subscriptionStoreName =>
      subscriptionPlatform.value == 'ios' ? 'App Store' : 'Google Play';

  /// Tienda a la que debe apuntar "Gestionar suscripción": la que contrató la
  /// suscripción y, si aún no hay ninguna, la del dispositivo.
  String get _managementStore => subscriptionPlatform.value.isNotEmpty
      ? subscriptionPlatform.value
      : _devicePlatform;

  String get managementStoreName =>
      _managementStore == 'ios' ? 'App Store' : 'Google Play';

  /// Dispositivo desde el que sí se puede cambiar o cancelar el plan.
  String get subscriptionDeviceName =>
      subscriptionPlatform.value == 'ios' ? 'iPhone o iPad' : 'Android';

  /// Corta cualquier compra cuando la suscripción vive en la otra tienda.
  /// Devuelve true si hay que abortar. La UI ya deshabilita los planes; esto
  /// es la red de seguridad (rutas alternativas, estado que cambia a mitad).
  bool _blockedByOtherStore() {
    if (!isManagedByOtherStore) return false;
    ToastService().show(
      title: 'Suscripción en $subscriptionStoreName',
      message: 'Tu suscripción se contrató en $subscriptionStoreName. Cambia '
          'de plan desde un $subscriptionDeviceName, o cancélala allí antes de '
          'suscribirte en esta tienda.',
      type: ToastType.warning,
    );
    return true;
  }

  @override
  void onInit() {
    super.onInit();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    isLoading.value = true;
    try {
      _listenCompany();
      _listenEmployees();

      final available = await iapRepository.init(companyId: _companyId);
      storeAvailable.value = available;
      if (!available) {
        loadDiagnostic.value = 'Tienda no disponible en este dispositivo';
        return;
      }

      _purchaseSub = iapRepository.purchaseUpdates.listen(_onPurchaseUpdate);
      final loaded = await iapRepository.loadProducts();
      products.assignAll(_sortedProducts(loaded));
      loadDiagnostic.value = iapRepository.lastLoadDiagnostic ?? '';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> reloadProducts() async {
    isLoading.value = true;
    try {
      final loaded = await iapRepository.loadProducts();
      products.assignAll(_sortedProducts(loaded));
      loadDiagnostic.value = iapRepository.lastLoadDiagnostic ?? '';
    } finally {
      isLoading.value = false;
    }
  }

  List<ProductDetails> _sortedProducts(List<ProductDetails> list) {
    final order = {
      for (int i = 0; i < IapPlans.all.length; i++) IapPlans.all[i].productId: i,
    };
    final sorted = [...list]..sort(
        (a, b) => (order[a.id] ?? 999).compareTo(order[b.id] ?? 999),
      );
    return sorted;
  }

  void _listenCompany() {
    if (_companyId.isEmpty) return;
    _companySub?.cancel();
    _companySub = FirebaseFirestore.instance
        .collection('companies')
        .doc(_companyId)
        .snapshots()
        .listen((doc) {
      final data = doc.data();
      if (data == null) return;
      final sub = (data['subscription'] as Map?)?.cast<String, dynamic>() ?? {};
      currentProductId.value = (sub['productId'] ?? '') as String;
      billingStatus.value = (sub['status'] ?? data['billingStatus'] ?? 'none') as String;
      contractedSeats.value = (data['contractedSeats'] as num?)?.toInt() ?? 1;
      final raw = sub['expiresAt'] ?? data['currentPeriodEnd'];
      if (raw is Timestamp) expiresAt.value = raw.toDate();
      autoRenewing.value = sub['autoRenewing'] == true;
      subscriptionPlatform.value = (sub['platform'] ?? '') as String;
    });
  }

  void _listenEmployees() {
    if (_companyId.isEmpty) return;
    _employeesSub?.cancel();
    _employeesSub = employeeRepository
        .streamEmployeesByCompanyId(_companyId)
        .listen((list) => employees.assignAll(list));
  }

  Future<void> _onPurchaseUpdate(PurchaseResult result) async {
    switch (result.status) {
      case PurchaseResultStatus.pending:
        isBuying.value = true;
        break;
      case PurchaseResultStatus.success:
        isBuying.value = false;
        // Solo avisamos si la compra la inició el usuario. Las transacciones que
        // StoreKit re-entrega al abrir la pantalla (backlog/renovaciones) se
        // procesan en silencio; la tarjeta se actualiza vía el listener de la
        // empresa en Firestore.
        if (_awaitingUserPurchase) {
          _awaitingUserPurchase = false;
          await _applyPendingDowngrade();
          ToastService().show(
            title: 'Éxito',
            message: 'Suscripción actualizada',
            type: ToastType.success,
          );
        }
        break;
      case PurchaseResultStatus.canceled:
        isBuying.value = false;
        _awaitingUserPurchase = false;
        _pendingDisableUids = const [];
        break;
      case PurchaseResultStatus.error:
        isBuying.value = false;
        // Igual que el éxito: solo mostramos el error si el usuario inició la
        // compra. Un fallo al verificar una transacción del backlog no debe
        // spamear (queda en el log del IapService).
        if (_awaitingUserPurchase) {
          _awaitingUserPurchase = false;
          _pendingDisableUids = const [];
          ToastService().show(
            title: 'Error',
            message: result.message ?? 'No se pudo completar la compra',
            type: ToastType.error,
          );
        }
        break;
    }
  }

  /// Aplica la desactivación de empleados elegida en el downgrade, una vez la
  /// compra está confirmada y verificada. El backend ya habrá ajustado plazas
  /// (updateEmployeesForBillingState); esto impone la selección del usuario.
  Future<void> _applyPendingDowngrade() async {
    final uids = _pendingDisableUids;
    _pendingDisableUids = const [];
    for (final uid in uids) {
      final emp = employees.firstWhereOrNull((e) => e.uid == uid);
      if (emp == null) continue;
      final updated = emp.copyWith(
        accountStatus: EmployeeAccountStatus.inactive,
        updatedAt: DateTime.now(),
      );
      final result = await employeeRepository.updateEmployee(updated);
      if (!result.success) {
        ToastService().show(
          title: 'Aviso',
          message: 'No se pudo desactivar a ${emp.name}. Revísalo en Empleados.',
          type: ToastType.warning,
        );
      }
    }
  }

  /// Comprueba si el plan elegido obliga a reducir empleados.
  /// Devuelve cuántos hay que desactivar (0 si no hace falta).
  int seatsToFreeFor(IapPlan plan) {
    final excess = billableEmployeeCount - plan.totalSeats;
    return excess > 0 ? excess : 0;
  }

  Future<void> buyPlan(String productId) async {
    if (_blockedByOtherStore()) return;
    final product = iapRepository.findProduct(productId);
    if (product == null) {
      ToastService().show(
        title: 'Error',
        message: 'Producto no disponible',
        type: ToastType.error,
      );
      return;
    }
    // Una compra real toma el relevo: que el temporizador de un "Restaurar"
    // previo no baje la bandera a mitad de compra.
    _restoreFlagTimer?.cancel();
    _awaitingUserPurchase = true;
    isBuying.value = true;
    try {
      final launched = await iapRepository.buy(product);
      if (!launched) {
        // La tienda rechazó ABRIR el flujo de compra (sin excepción ni evento
        // en purchaseStream): sin esto el spinner quedaría colgado.
        isBuying.value = false;
        _awaitingUserPurchase = false;
        ToastService().show(
          title: 'Error',
          message: 'No se pudo iniciar la compra. Inténtalo de nuevo.',
          type: ToastType.error,
        );
      }
    } catch (e) {
      isBuying.value = false;
      _awaitingUserPurchase = false;
      ToastService().show(
        title: 'Error',
        message: friendlyIapError(e),
        type: ToastType.error,
      );
    }
  }

  /// Desactiva los empleados seleccionados y luego ejecuta la compra.
  /// Se llama desde el modal cuando el usuario confirma a quién deshabilitar.
  Future<void> downgradeAndBuy({
    required String productId,
    required List<String> employeeUidsToDisable,
  }) async {
    if (_blockedByOtherStore()) return;
    final product = iapRepository.findProduct(productId);
    if (product == null) {
      ToastService().show(
        title: 'Error',
        message: 'Producto no disponible',
        type: ToastType.error,
      );
      return;
    }

    _restoreFlagTimer?.cancel();
    _awaitingUserPurchase = true;
    isBuying.value = true;
    // IMPORTANTE: la desactivación NO se aplica ahora. Queda pendiente y se
    // ejecuta en _onPurchaseUpdate cuando la compra se CONFIRMA (success).
    // buy() resuelve al abrirse la hoja de pago, no al completarse la compra:
    // si desactivásemos aquí y el usuario cancelase en la hoja, dejaríamos
    // empleados desactivados sin haber bajado de plan.
    _pendingDisableUids = List.of(employeeUidsToDisable);
    try {
      final launched = await iapRepository.buy(product);
      if (!launched) {
        isBuying.value = false;
        _awaitingUserPurchase = false;
        _pendingDisableUids = const [];
        ToastService().show(
          title: 'Error',
          message: 'No se pudo iniciar la compra. Inténtalo de nuevo.',
          type: ToastType.error,
        );
      }
    } catch (e) {
      isBuying.value = false;
      _awaitingUserPurchase = false;
      _pendingDisableUids = const [];
      ToastService().show(
        title: 'Error',
        message: friendlyIapError(e),
        type: ToastType.error,
      );
    }
  }

  /// Acción del botón "Restaurar" y del pull-to-refresh. Restaurar consulta la
  /// tienda del dispositivo: si la suscripción está en la otra, ahí no hay nada
  /// que restaurar, así que nos limitamos a recargar los productos.
  Future<void> refreshFromStore() async {
    if (isManagedByOtherStore) {
      await reloadProducts();
      return;
    }
    await restorePurchases();
  }

  Future<void> restorePurchases() async {
    _restoreFlagTimer?.cancel();
    _awaitingUserPurchase = true;
    isLoading.value = true;
    try {
      await iapRepository.restorePurchases();
    } finally {
      isLoading.value = false;
      // Si no había nada que restaurar, el purchaseStream no emite ningún
      // evento y nadie consumiría la bandera. Le damos un margen y la bajamos.
      _restoreFlagTimer = Timer(const Duration(seconds: 20), () {
        _awaitingUserPurchase = false;
      });
    }
  }

  Future<void> openStoreSubscriptionManagement() async {
    // El destino depende de DÓNDE se contrató la suscripción, no del
    // dispositivo: una suscripción de App Store no aparece en la lista de
    // Google Play (y viceversa), así que abrir la tienda del dispositivo
    // dejaba al usuario sin poder cancelar. Si aún no hay suscripción,
    // caemos en la tienda del dispositivo, que es donde comprará.
    final Uri url;
    if (_managementStore == 'ios') {
      // El esquema itms-apps:// solo lo entiende iOS; desde Android abrimos
      // la versión web de la gestión de suscripciones de Apple.
      url = Platform.isIOS
          ? Uri.parse('itms-apps://apps.apple.com/account/subscriptions')
          : Uri.parse('https://apps.apple.com/account/subscriptions');
    } else {
      url = Uri.parse('https://play.google.com/store/account/subscriptions');
    }
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ToastService().show(
        title: 'Error',
        message: 'No se pudo abrir la tienda',
        type: ToastType.error,
      );
    }
  }

  @visibleForTesting
  IapPlan? planFor(String productId) => IapPlans.byId(productId);

  @override
  void onClose() {
    _restoreFlagTimer?.cancel();
    _companySub?.cancel();
    _purchaseSub?.cancel();
    _employeesSub?.cancel();
    // Libera el listener del purchaseStream para que al volver a entrar se
    // re-inicialice con el companyId actual (evita listeners obsoletos).
    iapRepository.dispose();
    super.onClose();
  }
}
