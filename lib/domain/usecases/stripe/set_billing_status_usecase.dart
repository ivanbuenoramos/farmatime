import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/billing/billing_models.dart';
import 'package:farmatime/domain/repositories/stripe_repository.dart';

class SetBillingStatusUseCase {
  final StripeRepository repository;
  SetBillingStatusUseCase(this.repository);

  Future<Result<void>> call(String companyId, BillingStatus status) {
    return repository.setBillingStatus(companyId, status);
  }
}