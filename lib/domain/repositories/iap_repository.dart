import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:farmatime/data/services/iap_service.dart';

abstract class IapRepository {
  Future<bool> init({required String companyId});
  Future<List<ProductDetails>> loadProducts();
  ProductDetails? findProduct(String productId);
  Future<bool> buy(ProductDetails product);
  Future<void> restorePurchases();
  Stream<PurchaseResult> get purchaseUpdates;
  String? get lastLoadDiagnostic;

  /// Libera la suscripción al stream de compras para permitir re-inicializar
  /// con el companyId actual al volver a la pantalla.
  Future<void> dispose();
}
