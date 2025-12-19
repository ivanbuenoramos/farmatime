import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:farmatime/data/models/billing/billing_models.dart';
import 'package:farmatime/data/models/billing/create_seat_checkout_session_response.dart';
import 'package:farmatime/data/models/billing/payment_method_model.dart';
import 'package:farmatime/data/models/billing/preview_seat_change_response.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/stripe_repository.dart';
import 'package:firebase_core/firebase_core.dart';

class StripeRepositoryImpl implements StripeRepository {
  final FirebaseFunctions _functions;

  StripeRepositoryImpl({FirebaseFunctions? functions})
      : _functions = functions ??
          FirebaseFunctions.instanceFor(
            app: Firebase.app(),
            region: 'europe-west1',
          );

  @override
  Future<Result<List<InvoiceModel>>> listInvoices(String companyId, {int limit = 50}) async {
    try {
      final callable = _functions.httpsCallable('stripe_listInvoices');
      final res = await callable.call({'companyId': companyId, 'limit': limit});
      final data = Map<String, dynamic>.from(res.data as Map);
      final items = (data['items'] as List).cast<Map>().map((m) => InvoiceModel.fromJson(Map<String, dynamic>.from(m))).toList();
      return Result(success: true, data: items);
    } on FirebaseFunctionsException catch (e) {
      final pretty = '${e.code}: ${e.message ?? ''}';
      print(pretty);
      return Result(success: false, data: <InvoiceModel>[], errorCode: pretty);
    } catch (e) {
      print(e);
      return Result(success: false, data: <InvoiceModel>[], errorCode: 'unknown: $e');
    }
  }

  // 🔹 Lista tarjetas guardadas
  @override
  Future<Result<List<PaymentMethodModel>>> listPaymentMethods(String companyId) async {
    try {
      final callable = _functions.httpsCallable('stripe_listPaymentMethods');
      final res = await callable.call({'companyId': companyId});
      final data = Map<String, dynamic>.from(res.data);
      if (data['ok'] != true) {
        return Result(success: false, data: [], errorCode: 'response-failed');
      }
      final list = (data['paymentMethods'] as List)
          .map((e) => PaymentMethodModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return Result(success: true, data: list);
    } catch (e) {
      print(e);
      return Result(success: false, data: [], errorCode: e.toString());
    }
  }

  // 🔹 Establecer predeterminada
  @override
  Future<Result<void>> setDefaultPaymentMethod(String companyId, String paymentMethodId) async {
    try {
      final callable = _functions.httpsCallable('stripe_setDefaultPaymentMethod');
      await callable.call({'companyId': companyId, 'paymentMethodId': paymentMethodId});
      return Result(success: true, data: null);
    } catch (e) {
      print(e);
      return Result(success: false, data: null, errorCode: e.toString());
    }
  }

  // 🔹 Eliminar tarjeta
  @override
  Future<Result<void>> detachPaymentMethod(String companyId, String paymentMethodId) async {
    try {
      final callable = _functions.httpsCallable('stripe_detachPaymentMethod');
      await callable.call({'companyId': companyId, 'paymentMethodId': paymentMethodId});
      return Result(success: true, data: null);
    } catch (e) {
      print(e);
      return Result(success: false, data: null, errorCode: e.toString());
    }
  }

  @override
  Future<Result<void>> createCustomer({
    required String companyId,
  }) async {
    try {
      final callable = _functions.httpsCallable('stripe_createCustomer');
      await callable.call({'companyId': companyId});
      return Result(success: true, data: null);
    } catch (e) {
      return Result(data: null, success: false, errorCode: e.toString());
    }
  }

  @override
  Future<Result<CreateSeatCheckoutSessionResponse?>> createSeatCheckoutSession({
    required String companyId,
    required int newTotalSeats,
  }) async {
    try {
      final callable = _functions.httpsCallable('stripe_createSeatCheckoutSession');

      final resp = await callable.call(<String, dynamic>{
        'companyId': companyId,
        'newTotalSeats': newTotalSeats,
      });

      final data = Map<String, dynamic>.from(resp.data as Map);

      // Si la function no responde ok, lo tratamos como error “controlado”
      if (data['ok'] != true) {
        return Result(
          success: false,
          data: null,
          errorCode: data['errorCode']?.toString() ?? 'response-failed',
        );
      }

      return Result(
        success: true,
        data: CreateSeatCheckoutSessionResponse.fromJson(data),
      );
    } on FirebaseFunctionsException catch (e) {
      return Result(
        success: false,
        data: null,
        errorCode: '${e.code}: ${e.message ?? ''}'.trim(),
      );
    } catch (e) {
      return Result(
        success: false,
        data: null,
        errorCode: 'unknown: $e',
      );
    }
  }

  @override
  Future<Result<String?>> createBillingPortalSession({
    required String companyId,
  }) async {
    try {
      final callable =
          _functions.httpsCallable('stripe_createBillingPortalSession');

      final res = await callable.call({'companyId': companyId});
      final data = Map<String, dynamic>.from(res.data);

      final url = data['url'] as String?;
      if (url == null) {
        return Result(
          data: null, 
          success: false, 
          errorCode: 'No URL devuelta'
        );
      }

      return Result(
        success: true, 
        data: url
      );
    } catch (e) {
      return Result(
        data: null, 
        success: false, 
        errorCode: e.toString()
      );
    }
  }

  @override
  Future<Result<PreviewSeatChangeResponse?>> previewSeatChange({
    required String companyId,
    required int newTotalSeats,
  }) async {
    try {
      final callable =
          _functions.httpsCallable('stripe_previewSeatChange');

      final res = await callable.call({
        'companyId': companyId,
        'newTotalSeats': newTotalSeats,
      });

      final data = Map<String, dynamic>.from(res.data);

      return Result(
        success: true,
        data: PreviewSeatChangeResponse.fromJson(data),
      );
    } catch (e) {
      return Result(
        success: false,
        data: null,
        errorCode: 'stripe_preview_failed',
      );
    }
  }
}