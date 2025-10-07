import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/stripe_repository.dart';

class SyncSubscriptionFromStripeUseCase {
  final StripeRepository repository;
  SyncSubscriptionFromStripeUseCase(this.repository);

  Future<Result<void>> call(String companyId) {
    return repository.syncSubscriptionFromStripe(companyId);
  }
}