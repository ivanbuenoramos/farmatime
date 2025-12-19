import 'package:farmatime/data/models/billing/create_seat_checkout_session_response.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/stripe_repository.dart';

class CreateSeatCheckoutSessionUseCase {
  final StripeRepository _repo;

  CreateSeatCheckoutSessionUseCase(this._repo);

  Future<Result<CreateSeatCheckoutSessionResponse?>> call({
    required String companyId,
    required int newTotalSeats,
  }) {
    return _repo.createSeatCheckoutSession(
      companyId: companyId,
      newTotalSeats: newTotalSeats,
    );
  }
}