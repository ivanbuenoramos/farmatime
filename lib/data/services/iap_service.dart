import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart'
    show ReplacementMode;
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

import 'package:farmatime/core/iap/iap_plans.dart';
import 'package:farmatime/core/services/callable_http_client.dart';

/// Traduce cualquier error de compra (PlatformException de StoreKit, errores de
/// red, etc.) a un mensaje en lenguaje natural apto para mostrar al usuario.
/// NUNCA se debe enseñar el error técnico crudo.
String friendlyIapError(Object? e) {
  if (e is PlatformException) {
    switch (e.code) {
      case 'storekit_duplicate_product_object':
        return 'Ya tienes una compra en proceso para este plan. Espera unos '
            'segundos y vuelve a intentarlo.';
      case 'storekit_purchase_cancelled':
      case 'purchase_cancelled':
        return 'Has cancelado la compra.';
      case 'storekit_not_available':
      case 'billing_unavailable':
        return 'Las compras no están disponibles en este dispositivo ahora mismo.';
    }
  }
  final s = e?.toString().toLowerCase() ?? '';
  if (s.contains('cancel')) return 'Has cancelado la compra.';
  if (s.contains('network') ||
      s.contains('conexi') ||
      s.contains('timeout') ||
      s.contains('socket')) {
    return 'Problema de conexión. Revisa tu internet e inténtalo de nuevo.';
  }
  return 'No se pudo completar la compra. Inténtalo de nuevo.';
}

class IapService {
  IapService._();
  static final IapService instance = IapService._();

  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  final _purchaseUpdates = StreamController<PurchaseResult>.broadcast();

  Stream<PurchaseResult> get purchaseUpdates => _purchaseUpdates.stream;

  bool _initialized = false;
  bool _available = false;

  String? lastLoadDiagnostic;

  List<ProductDetails> products = [];

  Future<bool> init({required String companyId}) async {
    if (_initialized) return _available;
    _initialized = true;

    _available = await _iap.isAvailable();
    developer.log('init: store available=$_available', name: 'IapService');
    if (!_available) return false;

    // iOS: usar el delegate moderno para gestión de suscripciones desde Ajustes.
    if (Platform.isIOS) {
      final platform = _iap.getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      await platform.setDelegate(_PaymentQueueDelegate());
    }

    _sub?.cancel();
    _sub = _iap.purchaseStream.listen(
      (list) async {
        // Envolvemos en try/catch: si _onPurchaseUpdates lanza, igual emitimos
        // un error para que la UI quite el spinner (isBuying) y no se cuelgue.
        try {
          await _onPurchaseUpdates(list, companyId: companyId);
        } catch (e, st) {
          developer.log('purchaseStream callback error: $e',
              name: 'IapService', error: e, stackTrace: st);
          _purchaseUpdates.add(PurchaseResult.error(friendlyIapError(e)));
        }
      },
      onDone: () => _sub?.cancel(),
      onError: (e) {
        developer.log('purchaseStream onError: $e', name: 'IapService');
        _purchaseUpdates.add(PurchaseResult.error(friendlyIapError(e)));
      },
    );

    return true;
  }

  Future<void> loadProducts() async {
    if (!_available) {
      lastLoadDiagnostic = 'Tienda no disponible';
      return;
    }
    developer.log(
      'loadProducts: requesting ${IapPlans.productIds}',
      name: 'IapService',
    );
    final resp = await _iap.queryProductDetails(IapPlans.productIds);
    products = resp.productDetails;
    final foundIds = resp.productDetails.map((p) => p.id).toList();
    lastLoadDiagnostic =
        'Pedidos: ${IapPlans.productIds.toList()}\n'
        'Encontrados: $foundIds\n'
        'No encontrados: ${resp.notFoundIDs}\n'
        'Error: ${resp.error?.message ?? "ninguno"}';
    developer.log('loadProducts: $lastLoadDiagnostic', name: 'IapService');
  }

  ProductDetails? findProduct(String productId) {
    for (final p in products) {
      if (p.id == productId) return p;
    }
    return null;
  }

  Future<bool> buy(ProductDetails product) async {
    final param = await _buildPurchaseParam(product);
    try {
      return await _iap.buyNonConsumable(purchaseParam: param);
    } on PlatformException catch (e) {
      // Una compra anterior pudo quedar sin finalizar en la cola de StoreKit
      // (p.ej. por un crash), y StoreKit bloquea volver a comprar el mismo
      // producto. Limpiamos la cola y reintentamos una vez.
      if (Platform.isIOS && e.code == 'storekit_duplicate_product_object') {
        developer.log(
          'buy: transacción pendiente duplicada, limpiando cola y reintentando',
          name: 'IapService',
        );
        await _finishPendingIosTransactions();
        return await _iap.buyNonConsumable(purchaseParam: param);
      }
      rethrow;
    }
  }

  /// En Android, si ya hay una suscripción activa de OTRO plan, la compra debe
  /// enviarse como REEMPLAZO (ChangeSubscriptionParam); si no, Google Play crea
  /// una segunda suscripción en paralelo y el usuario paga dos planes a la vez.
  /// En iOS no aplica: los planes comparten subscription group y App Store hace
  /// el reemplazo automáticamente.
  Future<PurchaseParam> _buildPurchaseParam(ProductDetails product) async {
    if (!Platform.isAndroid) return PurchaseParam(productDetails: product);

    final old = await _findActiveAndroidPlanPurchase(exceptProductId: product.id);
    if (old == null) return PurchaseParam(productDetails: product);

    developer.log(
      'buy: cambio de plan Android ${old.productID} -> ${product.id}',
      name: 'IapService',
    );
    return GooglePlayPurchaseParam(
      productDetails: product,
      changeSubscriptionParam: ChangeSubscriptionParam(
        oldPurchaseDetails: old,
        // Cambio inmediato; el tiempo no consumido del plan anterior se abona
        // como crédito. Vale tanto para upgrade como para downgrade, y es
        // coherente con el backend, que aplica las plazas del plan nuevo al
        // verificar la compra.
        replacementMode: ReplacementMode.withTimeProration,
      ),
    );
  }

  /// Devuelve la compra activa en Google Play de cualquiera de nuestros planes
  /// (excluyendo [exceptProductId]), o null si no hay ninguna o no se pudo
  /// consultar. Si falla la consulta compramos sin reemplazo: peor UX (posible
  /// doble suscripción) pero no bloquea la compra.
  Future<GooglePlayPurchaseDetails?> _findActiveAndroidPlanPurchase({
    required String exceptProductId,
  }) async {
    try {
      final addition =
          _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final resp = await addition.queryPastPurchases();
      if (resp.error != null) {
        developer.log(
          'queryPastPurchases error: ${resp.error!.message}',
          name: 'IapService',
        );
        return null;
      }
      for (final p in resp.pastPurchases) {
        if (p.productID == exceptProductId) continue;
        if (IapPlans.byId(p.productID) == null) continue;
        if (p.status == PurchaseStatus.purchased ||
            p.status == PurchaseStatus.restored) {
          return p;
        }
      }
    } catch (e) {
      developer.log(
        'queryPastPurchases falló (se compra sin reemplazo): $e',
        name: 'IapService',
      );
    }
    return null;
  }

  /// Finaliza transacciones StoreKit pendientes (iOS) que quedaron sin cerrar
  /// y bloquean nuevas compras (`storekit_duplicate_product_object`). No toca
  /// las que siguen en estado `.purchasing` (no se pueden finalizar; las
  /// resuelve Apple). El estado de suscripción es autoritativo en el backend,
  /// así que finalizar transacciones locales obsoletas es seguro.
  Future<void> _finishPendingIosTransactions() async {
    if (!Platform.isIOS) return;
    try {
      final queue = SKPaymentQueueWrapper();
      final txns = await queue.transactions();
      for (final tx in txns) {
        if (tx.transactionState ==
            SKPaymentTransactionStateWrapper.purchasing) {
          continue;
        }
        try {
          await queue.finishTransaction(tx);
          developer.log(
            'finishPending: finalizada ${tx.payment.productIdentifier} '
            '(${tx.transactionState})',
            name: 'IapService',
          );
        } catch (e) {
          developer.log('finishPending: error finalizando: $e',
              name: 'IapService');
        }
      }
    } catch (e) {
      developer.log('finishPending: error listando transacciones: $e',
          name: 'IapService');
    }
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  Future<void> _onPurchaseUpdates(
    List<PurchaseDetails> list, {
    required String companyId,
  }) async {
    for (final purchase in list) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _purchaseUpdates.add(PurchaseResult.pending(purchase.productID));
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final isLocalStoreKit = _looksLikeLocalStoreKit(purchase);
          if (isLocalStoreKit && kDebugMode) {
            developer.log(
              'verifyPurchase: detected LOCAL StoreKit transaction, '
              'skipping backend and writing mock subscription to Firestore',
              name: 'IapService',
            );
            await _writeMockSubscription(
              companyId: companyId,
              productId: purchase.productID,
            );
            _purchaseUpdates.add(PurchaseResult.success(purchase.productID));
            await _safeComplete(purchase);
          } else {
            final r = await _verifyWithBackend(
              purchase,
              companyId: companyId,
            );
            if (r.error == null) {
              _purchaseUpdates.add(PurchaseResult.success(purchase.productID));
              // Solo finalizamos la transacción TRAS verificar con éxito.
              await _safeComplete(purchase);
            } else {
              _purchaseUpdates.add(PurchaseResult.error(r.error!));
              // Si el rechazo es PERMANENTE (p.ej. la suscripción pertenece a
              // otra empresa), finalizamos la transacción para no entrar en
              // bucle. Si es transitorio (red/backend), la dejamos PENDIENTE:
              // StoreKit la re-entrega al reabrir/restaurar y se reintenta.
              if (r.permanent) {
                await _safeComplete(purchase);
              }
            }
          }
          break;

        case PurchaseStatus.error:
          // El mensaje nativo de StoreKit es técnico/inglés: NO lo mostramos.
          developer.log('purchase error: ${purchase.error}', name: 'IapService');
          _purchaseUpdates.add(
            PurchaseResult.error(friendlyIapError(purchase.error)),
          );
          // error/canceled: la transacción ya está resuelta por StoreKit; la
          // finalizamos para que no quede en la cola.
          await _safeComplete(purchase);
          break;

        case PurchaseStatus.canceled:
          _purchaseUpdates.add(PurchaseResult.canceled(purchase.productID));
          await _safeComplete(purchase);
          break;
      }
    }
  }

  /// Finaliza la transacción de StoreKit sin propagar excepciones (un fallo de
  /// completePurchase no debe colgar el flujo ni tirar la app).
  Future<void> _safeComplete(PurchaseDetails purchase) async {
    if (!purchase.pendingCompletePurchase) return;
    try {
      await _iap.completePurchase(purchase);
    } catch (e) {
      developer.log('completePurchase falló (no-fatal): $e', name: 'IapService');
    }
  }

  /// Indica si debemos SIMULAR la suscripción localmente (StoreKit local con
  /// fichero .storekit en el scheme) en vez de validar contra el backend.
  ///
  /// Por defecto usamos SIEMPRE App Store Connect (sandbox) + backend real,
  /// también en debug — igual que TestFlight/release. Así las pruebas en debug
  /// leen las suscripciones reales de App Store Connect.
  ///
  /// Solo si lanzas con `--dart-define=USE_LOCAL_STOREKIT=true` (y el scheme
  /// tiene un fichero Configuration.storekit seleccionado) volvemos al mock
  /// local que escribe directamente en Firestore (requiere emulador).
  bool _looksLikeLocalStoreKit(PurchaseDetails purchase) {
    if (!kDebugMode) return false;
    if (!Platform.isIOS) return false;
    return const bool.fromEnvironment('USE_LOCAL_STOREKIT');
  }

  /// En modo debug con StoreKit local, escribimos directamente el estado
  /// de suscripción en Firestore. Esto solo se ejecuta en debug (kDebugMode).
  ///
  /// IMPORTANTE: las reglas de Firestore de PRODUCCIÓN bloquean que el cliente
  /// escriba `billingStatus`/`contractedSeats`/`subscription` (solo el backend
  /// admin puede). Por tanto este mock solo funciona apuntando al EMULADOR de
  /// Firestore, no contra el proyecto real. En release este método nunca se
  /// invoca (ver _looksLikeLocalStoreKit, que exige kDebugMode).
  Future<void> _writeMockSubscription({
    required String companyId,
    required String productId,
  }) async {
    if (companyId.isEmpty) return;
    final plan = IapPlans.byId(productId);
    if (plan == null) return;

    final now = DateTime.now();
    final expires = now.add(const Duration(days: 30));

    await FirebaseFirestore.instance.collection('companies').doc(companyId).set({
      'subscription': {
        'platform': 'ios',
        'productId': productId,
        'status': 'active',
        'originalTransactionId': 'mock-${now.millisecondsSinceEpoch}',
        'expiresAt': Timestamp.fromDate(expires),
        'currentPeriodStart': Timestamp.fromDate(now),
        'autoRenewing': true,
        'environment': 'sandbox-local',
      },
      'billingStatus': 'active',
      'contractedSeats': plan.totalSeats,
      'currentPeriodStart': Timestamp.fromDate(now),
      'currentPeriodEnd': Timestamp.fromDate(expires),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Verifica la compra contra el backend.
  /// - error: null si todo OK; si no, mensaje legible (el real del backend).
  /// - permanent: true si el error NO se resolverá reintentando (p.ej. la
  ///   suscripción ya pertenece a otra empresa, producto/recibo inválido). En
  ///   ese caso conviene finalizar la transacción y no dejarla en bucle.
  Future<({String? error, bool permanent})> _verifyWithBackend(
    PurchaseDetails purchase, {
    required String companyId,
  }) async {
    try {
      final payload = Platform.isIOS
          ? {
              'companyId': companyId,
              'platform': 'ios',
              'productId': purchase.productID,
              'transactionId': purchase.purchaseID,
              // Recibo base64: permite el fallback verifyReceipt en el backend
              // si la App Store Server API falla (p.ej. credenciales mal puestas).
              'receiptData': purchase.verificationData.serverVerificationData,
            }
          : {
              'companyId': companyId,
              'platform': 'android',
              'productId': purchase.productID,
              'purchaseToken': purchase.verificationData.serverVerificationData,
            };

      developer.log(
        'verifyPurchase: calling backend with transactionId='
        '${purchase.purchaseID} (receipt ${purchase.verificationData.serverVerificationData.length} bytes)',
        name: 'IapService',
      );

      // HTTP directo en lugar de httpsCallable: el SDK nativo de
      // FirebaseFunctions aborta la app en release (ver CallableHttpClient).
      final resp = await CallableHttpClient.call('iap_verifyPurchase', payload);
      developer.log(
        'verifyPurchase: success, response=$resp',
        name: 'IapService',
      );
      return (error: null, permanent: false);
    } on CallableException catch (e, st) {
      developer.log(
        'verifyPurchase: backend error ${e.status}: ${e.message}',
        name: 'IapService',
        error: e,
        stackTrace: st,
      );
      // Estos códigos no se arreglan reintentando: la transacción debe
      // finalizarse para no quedar en bucle.
      const permanentStatuses = {
        'FAILED_PRECONDITION', // suscripción ya vinculada a otra empresa
        'INVALID_ARGUMENT', // producto/recibo no coincide
        'PERMISSION_DENIED', // bundleId inválido
      };
      final permanent = permanentStatuses.contains(e.status);
      return (error: e.message, permanent: permanent);
    } catch (e, st) {
      developer.log(
        'verifyPurchase: unexpected error',
        name: 'IapService',
        error: e,
        stackTrace: st,
      );
      // Error de red/desconocido: transitorio → se reintenta. NO mostramos el
      // error técnico crudo al usuario (queda en el log de arriba).
      return (
        error: 'No se pudo verificar la compra. Revisa tu conexión e '
            'inténtalo de nuevo.',
        permanent: false,
      );
    }
  }

  /// Libera la suscripción al purchaseStream y permite re-inicializar con el
  /// companyId actual al volver a entrar. NO cerramos _purchaseUpdates (es un
  /// broadcast del singleton que se reutiliza en la siguiente init()).
  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _initialized = false;
  }
}

class _PaymentQueueDelegate implements SKPaymentQueueDelegateWrapper {
  @override
  bool shouldContinueTransaction(
    SKPaymentTransactionWrapper transaction,
    SKStorefrontWrapper storefront,
  ) => true;

  @override
  bool shouldShowPriceConsent() => false;
}

enum PurchaseResultStatus { pending, success, canceled, error }

class PurchaseResult {
  final PurchaseResultStatus status;
  final String? productId;
  final String? message;

  const PurchaseResult._(this.status, {this.productId, this.message});

  factory PurchaseResult.pending(String productId) =>
      PurchaseResult._(PurchaseResultStatus.pending, productId: productId);
  factory PurchaseResult.success(String productId) =>
      PurchaseResult._(PurchaseResultStatus.success, productId: productId);
  factory PurchaseResult.canceled(String productId) =>
      PurchaseResult._(PurchaseResultStatus.canceled, productId: productId);
  factory PurchaseResult.error(String message) =>
      PurchaseResult._(PurchaseResultStatus.error, message: message);
}
