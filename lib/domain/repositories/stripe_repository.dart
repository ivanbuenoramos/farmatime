import 'package:farmatime/data/models/billing/payment_method_model.dart';
import 'package:farmatime/data/models/billing/setup_card_payload.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/billing/billing_models.dart';
import 'package:farmatime/data/models/billing/prepare_payment_models.dart';



enum ProrationBehavior { createProrations, none }

abstract class StripeRepository {
  /// Crea Customer + Subscription (si no existen) y sincroniza Firestore.
  Future<Result<void>> createCustomerAndSubscription(String companyId, {int initialQuantity = 1});

  /// Actualiza la cantidad de asientos (quantity) en Stripe.
  Future<Result<void>> updateSubscriptionQuantity(
    String companyId,
    int newQuantity, {
    ProrationBehavior prorationBehavior = ProrationBehavior.createProrations,
  });

  /// Devuelve URL del portal de cliente (Stripe Billing Portal).
  Future<Result<String>> createBillingPortalSession(String companyId, {String? returnUrl});

  /// Sincroniza manualmente desde Stripe → Firestore (por si hace falta).
  Future<Result<void>> syncSubscriptionFromStripe(String companyId);

  /// (Opcional) Cambia estado (sólo útil sin Stripe, normalmente lo hacen webhooks).
  Future<Result<void>> setBillingStatus(String companyId, BillingStatus status);

  Future<Result<List<InvoiceModel>>> listInvoices(String companyId, {int limit = 50});

  Future<Result<PrepareSeatChangePaymentResponse?>> prepareSeatChangePayment({
    required String companyId,
    required int newQuantity,
  });

  Future<Result<List<PaymentMethodModel>>> listPaymentMethods(String companyId);

  Future<Result<void>> setDefaultPaymentMethod(String companyId, String paymentMethodId);
  
  Future<Result<void>> detachPaymentMethod(String companyId, String paymentMethodId);
  
  Future<Result<SetupCardPayload?>> createSetupIntent(String companyId);
}
