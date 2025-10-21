import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/stripe_repository.dart';

class DetachPaymentMethodUseCase {
  final StripeRepository repo;
  DetachPaymentMethodUseCase(this.repo);
  Future<Result<void>> call(String companyId, String paymentMethodId) {
    return repo.detachPaymentMethod(companyId, paymentMethodId);
  }
}