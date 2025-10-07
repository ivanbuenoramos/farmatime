import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/billing/billing_models.dart';
import 'package:farmatime/domain/repositories/stripe_repository.dart';



class ListInvoicesUseCase {
  final StripeRepository repo;
  ListInvoicesUseCase(this.repo);

  Future<Result<List<InvoiceModel>>> call(String companyId, {int limit = 50}) {
    return repo.listInvoices(companyId, limit: limit);
  }
}