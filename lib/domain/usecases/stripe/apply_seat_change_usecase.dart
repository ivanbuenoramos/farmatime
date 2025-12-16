import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/stripe_repository.dart';
import 'package:farmatime/data/models/billing/seat_change_apply_response.dart';

class ApplySeatChangeUseCase {
  final StripeRepository repository;
  ApplySeatChangeUseCase(this.repository);

  Future<Result<SeatChangeApplyResponse?>> call({
    required String companyId,
    required int newTotalSeats,
    required List<String> employeesToDeactivate,
  }) =>
      repository.applySeatChange(
        companyId: companyId,
        newTotalSeats: newTotalSeats,
        employeesToDeactivate: employeesToDeactivate,
      );
}