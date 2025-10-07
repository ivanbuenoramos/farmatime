import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/company_subscription.dart';



abstract class SubscriptionRepository {

  Future<Result<CompanySubscription?>> getCurrent(String companyId);

  Future<Result<void>> upsert(String companyId, CompanySubscription sub);

  Future<Result<void>> updateStatus(String companyId, SubscriptionStatus status);

  Future<Result<void>> updateNextRenewal(String companyId, DateTime date);
}