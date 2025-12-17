import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/stripe_repository.dart';
import 'package:farmatime/data/models/billing/prepare_seat_payment_sheet_response.dart';

class PrepareSeatPaymentSheetUseCase {
  final StripeRepository repo;

  PrepareSeatPaymentSheetUseCase(this.repo);

  Future<Result<PrepareSeatPaymentSheetResponse?>> call({
    required String companyId,
    required int newTotalSeats,
  }) {
    return repo.prepareSeatPaymentSheet(
      companyId: companyId,
      newTotalSeats: newTotalSeats,
    );
  }
}