import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/billing_repository.dart';

class UpdateOccupiedSeatsUseCase {
  final BillingRepository repository;
  UpdateOccupiedSeatsUseCase(this.repository);

  Future<Result<void>> call(String companyId, int occupiedSeats) {
    return repository.updateOccupiedSeats(companyId, occupiedSeats);
  }
}