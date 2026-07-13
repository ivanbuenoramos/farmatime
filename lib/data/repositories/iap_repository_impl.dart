import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:farmatime/data/services/iap_service.dart';
import 'package:farmatime/domain/repositories/iap_repository.dart';

class IapRepositoryImpl implements IapRepository {
  final IapService _service = IapService.instance;

  @override
  Future<bool> init({required String companyId}) =>
      _service.init(companyId: companyId);

  @override
  Future<List<ProductDetails>> loadProducts() async {
    await _service.loadProducts();
    return _service.products;
  }

  @override
  ProductDetails? findProduct(String productId) =>
      _service.findProduct(productId);

  @override
  Future<bool> buy(ProductDetails product) => _service.buy(product);

  @override
  Future<void> restorePurchases() => _service.restorePurchases();

  @override
  Stream<PurchaseResult> get purchaseUpdates => _service.purchaseUpdates;

  @override
  String? get lastLoadDiagnostic => _service.lastLoadDiagnostic;

  @override
  Future<void> dispose() => _service.dispose();
}
