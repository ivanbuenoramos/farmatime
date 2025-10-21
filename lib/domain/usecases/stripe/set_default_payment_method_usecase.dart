import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/stripe_repository.dart';

class SetDefaultPaymentMethodUseCase {
  final StripeRepository repo;
  SetDefaultPaymentMethodUseCase(this.repo);
  Future<Result<void>> call(String companyId, String paymentMethodId) {
    return repo.setDefaultPaymentMethod(companyId, paymentMethodId);
  }
}