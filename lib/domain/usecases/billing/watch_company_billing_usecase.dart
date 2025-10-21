import 'package:farmatime/data/models/billing/billing_models.dart';
import 'package:farmatime/domain/repositories/billing_repository.dart';

class WatchCompanyBillingUseCase {
  final BillingRepository repository;
  WatchCompanyBillingUseCase(this.repository);

  Stream<CompanyBilling?> call(String companyId) {
    return repository.watchCompanyBilling(companyId);
  }
}