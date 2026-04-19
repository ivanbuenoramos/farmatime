import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/stripe_repository.dart';

class CreateBillingPortalSessionUseCase {
  final StripeRepository repository;

  CreateBillingPortalSessionUseCase(this.repository);

  Future<Result<String?>> call({
    required String companyId,
    String? returnUrl,
  }) {
    return repository.createBillingPortalSession(
      companyId: companyId,
      returnUrl: returnUrl,
    );
  }
}