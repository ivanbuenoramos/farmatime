import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/billing/billing_models.dart';
import 'package:farmatime/domain/repositories/billing_repository.dart';

class GetCompanyBillingUseCase {
  final BillingRepository repository;
  GetCompanyBillingUseCase(this.repository);

  Future<Result<CompanyBilling?>> call(String companyId) {
    return repository.getCompanyBilling(companyId);
  }
}