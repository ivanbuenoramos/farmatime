import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/stripe_repository.dart';

class UpdateSubscriptionQuantityUseCase {
  final StripeRepository repository;
  UpdateSubscriptionQuantityUseCase(this.repository);

  Future<Result<void>> call(
    String companyId,
    int newQuantity, {
    ProrationBehavior prorationBehavior = ProrationBehavior.createProrations,
  }) {
    return repository.updateSubscriptionQuantity(
      companyId,
      newQuantity,
      prorationBehavior: prorationBehavior,
    );
  }
}