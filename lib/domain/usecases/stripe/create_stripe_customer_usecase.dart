import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/stripe_repository.dart';

class CreateStripeCustomerUseCase {
  final StripeRepository repository;

  CreateStripeCustomerUseCase(this.repository);

  Future<Result<void>> call({
    required String companyId,
  }) {
    return repository.createCustomer(companyId: companyId);
  }
}