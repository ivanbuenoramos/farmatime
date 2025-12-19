import 'package:farmatime/data/models/billing/payment_method_model.dart';
import 'package:farmatime/data/models/billing/preview_seat_change_response.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/billing/billing_models.dart';
import 'package:farmatime/data/models/billing/create_seat_checkout_session_response.dart';



enum ProrationBehavior { createProrations, none }

abstract class StripeRepository {

  Future<Result<void>> createCustomer({
    required String companyId,
  });

  Future<Result<List<InvoiceModel>>> listInvoices(String companyId, {int limit = 50});

  Future<Result<List<PaymentMethodModel>>> listPaymentMethods(String companyId);

  Future<Result<void>> setDefaultPaymentMethod(String companyId, String paymentMethodId);
  
  Future<Result<void>> detachPaymentMethod(String companyId, String paymentMethodId);

  Future<Result<String?>> createBillingPortalSession({
    required String companyId,
  });

  Future<Result<CreateSeatCheckoutSessionResponse?>> createSeatCheckoutSession({
    required String companyId,
    required int newTotalSeats,
  });

  Future<Result<PreviewSeatChangeResponse?>> previewSeatChange({
    required String companyId,
    required int newTotalSeats,
  });
}
