import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/stripe_repository.dart';
import 'package:farmatime/data/models/billing/stripe_open_invoice_payment_model.dart';



class GetOpenInvoicePaymentUseCase {
  final StripeRepository stripeRepository;

  GetOpenInvoicePaymentUseCase(this.stripeRepository);

  Future<Result<StripeOpenInvoicePaymentModel?>> call({
    required String companyId,
  }) {
    return stripeRepository.getOpenInvoicePayment(companyId: companyId);
  }
}