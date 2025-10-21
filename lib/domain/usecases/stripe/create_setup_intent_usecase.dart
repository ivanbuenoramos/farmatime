import 'package:farmatime/data/models/billing/setup_card_payload.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/stripe_repository.dart';

class CreateSetupIntentUseCase {
  final StripeRepository repo;
  CreateSetupIntentUseCase(this.repo);
  Future<Result<SetupCardPayload?>> call(String companyId) {
    return repo.createSetupIntent(companyId);
  }
}