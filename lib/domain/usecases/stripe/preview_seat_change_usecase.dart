import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/stripe_repository.dart';
import 'package:farmatime/data/models/billing/preview_seat_change_response.dart';



class PreviewSeatChangeUseCase {
  final StripeRepository repository;

  PreviewSeatChangeUseCase(this.repository);

  Future<Result<PreviewSeatChangeResponse?>> call({
    required String companyId,
    required int newTotalSeats,
  }) {
    return repository.previewSeatChange(
      companyId: companyId,
      newTotalSeats: newTotalSeats,
    );
  }
}