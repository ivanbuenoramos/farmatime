import 'package:farmatime/data/models/billing/update_seats_and_pay_result.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/stripe_repository.dart';

class UpdateSeatsAndPayUseCase {
  final StripeRepository repository;

  UpdateSeatsAndPayUseCase(this.repository);

  Future<Result<UpdateSeatsAndPayResult?>> call({
    required String companyId,
    required int newTotalSeats,
  }) {
    return repository.updateSeatsAndPay(
      companyId: companyId,
      newTotalSeats: newTotalSeats,
    );
  }
}