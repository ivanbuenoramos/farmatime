import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/company_subscription.dart';
import 'package:farmatime/domain/repositories/subscription_repository.dart';



class GetCurrentSubscriptionUseCase {
  final SubscriptionRepository repository;
  GetCurrentSubscriptionUseCase(this.repository);

  Future<Result<CompanySubscription?>> call(String companyId) {
    return repository.getCurrent(companyId);
  }
}