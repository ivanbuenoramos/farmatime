import 'package:farmatime/data/models/billing/seat_change_preview_response.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/stripe_repository.dart';

class PreviewSeatChangeUseCase {
  final StripeRepository repository;
  PreviewSeatChangeUseCase(this.repository);

  Future<Result<SeatChangePreviewResponse?>> call({
    required String companyId,
    required int newTotalSeats,
  }) {
    return repository.previewSeatChange(
      companyId: companyId,
      newTotalSeats: newTotalSeats,
    );
  }
}