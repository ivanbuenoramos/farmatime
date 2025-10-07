import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/company_subscription.dart';
import 'package:farmatime/domain/repositories/subscription_repository.dart';



class UpdateSubscriptionStatusUseCase {
  final SubscriptionRepository repository;
  UpdateSubscriptionStatusUseCase(this.repository);

  Future<Result<void>> call(String companyId, SubscriptionStatus status) {
    return repository.updateStatus(companyId, status);
  }
}