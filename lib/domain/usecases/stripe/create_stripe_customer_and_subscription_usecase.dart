import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/stripe_repository.dart';



class CreateStripeCustomerAndSubscriptionUseCase {
  final StripeRepository repository;
  CreateStripeCustomerAndSubscriptionUseCase(this.repository);

  /// initialQuantity: normalmente 1 si regalas el primer asiento con la tarifa por niveles
  Future<Result<void>> call(String companyId, {int initialQuantity = 1}) {
    return repository.createCustomerAndSubscription(
      companyId,
      initialQuantity: initialQuantity,
    );
  }
}