import 'package:farmatime/data/models/billing/stripe_incomplete_payment_model.dart.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/stripe_repository.dart';

class GetIncompletePaymentUseCase {
  final StripeRepository repository;

  GetIncompletePaymentUseCase(this.repository);

  Future<Result<StripeIncompletePaymentModel?>> call(String companyId) {
    return repository.getIncompletePayment(companyId: companyId);
  }
}