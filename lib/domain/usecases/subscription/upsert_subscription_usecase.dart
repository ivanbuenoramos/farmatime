import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/company_subscription.dart';
import 'package:farmatime/domain/repositories/subscription_repository.dart';



class UpsertSubscriptionUseCase {
  final SubscriptionRepository repository;
  UpsertSubscriptionUseCase(this.repository);

  Future<Result<void>> call(String companyId, CompanySubscription sub) {
    return repository.upsert(companyId, sub);
  }
}