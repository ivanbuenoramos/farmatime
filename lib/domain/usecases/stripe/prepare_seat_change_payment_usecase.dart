import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/stripe_repository.dart';
import 'package:farmatime/data/models/billing/prepare_payment_models.dart';


class PrepareSeatChangePaymentUseCase {
  final StripeRepository repository;

  PrepareSeatChangePaymentUseCase(this.repository);

  Future<Result<PrepareSeatChangePaymentResponse?>> call({
    required String companyId,
    required int newQuantity,
  }) {
    return repository.prepareSeatChangePayment(
      companyId: companyId,
      newTotalSeats: newQuantity,
    );
  }
}