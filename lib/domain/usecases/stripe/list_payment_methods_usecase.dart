import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/billing/payment_method_model.dart';
import 'package:farmatime/domain/repositories/stripe_repository.dart';

class ListPaymentMethodsUseCase {
  final StripeRepository repo;
  ListPaymentMethodsUseCase(this.repo);
  Future<Result<List<PaymentMethodModel>>> call(String companyId) {
    return repo.listPaymentMethods(companyId);
  }
}