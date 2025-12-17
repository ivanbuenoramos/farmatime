import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:farmatime/data/models/billing/billing_models.dart';
import 'package:farmatime/data/models/billing/prepare_seat_payment_sheet_response.dart';
import 'package:farmatime/data/models/billing/payment_method_model.dart';
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

  // @override
  // Future<Result<void>> createCustomerAndSubscription(
  //   String companyId, {int initialQuantity = 1}
  // ) async {
  //   try {
  //     final callable =
  //         _functions.httpsCallable('stripe_createCustomerAndSubscription');
  //     await callable.call({
  //       'companyId': companyId,
  //       // 'initialQuantity': initialQuantity,
  //     });
  //     return Result(success: true, data: null);
  //   } on FirebaseFunctionsException catch (e) {
  //     print('${e.code}: ${e.message}');
  //     return Result(success: false, data: null, errorCode: '${e.code}: ${e.message}');
  //   } catch (e) {
  //     print(e);
  //     return Result(success: false, data: null, errorCode: 'unknown: $e');
  //   }
  // }


  // @override
  // Future<Result<void>> updateSubscriptionQuantity(
  //   String companyId,
  //   int totalSeats, { // puedes renombrar el param a totalSeats cuando quieras
  //   ProrationBehavior prorationBehavior = ProrationBehavior.createProrations,
  // }) async {
  //   try {
  //     final callable = _functions.httpsCallable('stripe_updateSubscriptionQuantity');
  //     await callable.call({
  //       'companyId': companyId,
  //       'totalSeats': totalSeats,
  //       'proration_behavior': prorationBehavior == ProrationBehavior.createProrations
  //           ? 'create_prorations'
  //           : 'none',
  //     });
  //     return Result(success: true, data: null);
  //   } on FirebaseFunctionsException catch (e) {
  //     print(e);
  //     return Result(success: false, data: null, errorCode: e.code);
  //   } catch (e) {
  //     print(e);
  //     return Result(success: false, data: null, errorCode: 'unknown-error');
  //   }
  // }

  // @override
  // Future<Result<String?>> createBillingPortalSession(String companyId, {String? returnUrl}) async {
  //   try {
  //     final callable = _functions.httpsCallable('stripe_createBillingPortalSession');
  //     final res = await callable.call({'companyId': companyId, 'returnUrl': returnUrl});
  //     final url = (res.data?['url'] as String?) ?? '';
  //     if (url.isEmpty) {
  //       return Result(success: false, data: '', errorCode: 'missing-url');
  //     }
  //     return Result(success: true, data: url);
  //   } on FirebaseFunctionsException catch (e) {
  //     print(e);
  //     return Result(success: false, data: '', errorCode: e.code);
  //   } catch (e) {
  //     print(e);
  //     return Result(success: false, data: '', errorCode: 'unknown-error');
  //   }
  // }

  // @override
  // Future<Result<void>> syncSubscriptionFromStripe(String companyId) async {
  //   try {
  //     final callable = _functions.httpsCallable('stripe_syncSubscription');
  //     await callable.call({'companyId': companyId});
  //     return Result(success: true, data: null);
  //   } on FirebaseFunctionsException catch (e) {
  //     print(e);
  //     return Result(success: false, data: null, errorCode: e.code);
  //   } catch (e) {
  //     print(e);
  //     return Result(success: false, data: null, errorCode: 'unknown-error');
  //   }
  // }

  // @override
  // Future<Result<void>> setBillingStatus(String companyId, BillingStatus status) async {
  //   try {
  //     final callable = _functions.httpsCallable('stripe_setBillingStatus');
  //     await callable.call({'companyId': companyId, 'status': status.nameStr});
  //     return Result(success: true, data: null);
  //   } on FirebaseFunctionsException catch (e) {
  //     print(e);
  //     return Result(success: false, data: null, errorCode: e.code);
  //   } catch (e) {
  //     print(e);
  //     return Result(success: false, data: null, errorCode: 'unknown-error');
  //   }
  // }

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

  // @override
  // Future<Result<SeatChangePreviewResponse?>> previewSeatChange({
  //   required String companyId,
  //   required int newTotalSeats,
  // }) async {
  //   try {
  //     final callable = _functions.httpsCallable('stripe_previewSeatChange');
  //     final resp = await callable.call({
  //       'companyId': companyId,
  //       'newTotalSeats': newTotalSeats,
  //     });
  //     final data = Map<String, dynamic>.from(resp.data as Map);
  //     return Result(success: true, data: SeatChangePreviewResponse.fromJson(data));
  //   } catch (e) {
  //     return Result(success: false, data: null, errorCode: e.toString());
  //   }
  // }

  // @override
  // Future<Result<SeatChangeApplyResponse?>> applySeatChange({
  //   required String companyId,
  //   required int newTotalSeats,
  //   required List<String> employeesToDeactivate,
  // }) async {
  //   try {
  //     final callable = _functions.httpsCallable('stripe_applySeatChange');
  //     final resp = await callable.call({
  //       'companyId': companyId,
  //       'newTotalSeats': newTotalSeats,
  //       'employeesToDeactivate': employeesToDeactivate,
  //     });
  //     final data = Map<String, dynamic>.from(resp.data as Map);
  //     return Result(success: true, data: SeatChangeApplyResponse.fromJson(data));
  //   } catch (e) {
  //     return Result(success: false, data: null, errorCode: e.toString());
  //   }
  // }

  // @override
  // Future<Result<PrepareSeatChangePaymentResponse?>> prepareSeatChangePayment({
  //   required String companyId,
  //   required int newTotalSeats,
  // }) async {
  //   try {
  //     final callable = _functions.httpsCallable('stripe_prepareSeatChangePayment');
  //     final resp = await callable.call(<String, dynamic>{
  //       'companyId': companyId,
  //       'newTotalSeats': newTotalSeats,
  //     });

  //     final data = Map<String, dynamic>.from(resp.data as Map);
  //     return Result(
  //       success: true,
  //       data: PrepareSeatChangePaymentResponse.fromJson(data),
  //     );
  //   } catch (e) {
  //     return Result(success: false, data: null, errorCode: e.toString());
  //   }
  // }

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

  // 🔹 Crear SetupIntent (añadir tarjeta)
  // @override
  // Future<Result<SetupCardPayload?>> createSetupIntent(String companyId) async {
  //   try {
  //     final callable = _functions.httpsCallable('stripe_createSetupIntent');
  //     final res = await callable.call({'companyId': companyId});
  //     final data = Map<String, dynamic>.from(res.data);
  //     if (data['ok'] != true) {
  //       return Result(success: false, data: null, errorCode: 'response-failed');
  //     }
  //     final payload = SetupCardPayload(
  //       customerId: data['customerId'],
  //       ephemeralKeySecret: data['ephemeralKeySecret'],
  //       setupIntentClientSecret: data['setupIntentClientSecret'],
  //     );
  //     return Result(success: true, data: payload);
  //   } catch (e) {
  //     print(e);
  //     return Result(success: false, data: null, errorCode: e.toString());
  //   }
  // }

  // @override
  // Future<Result<StripeIncompletePaymentModel?>> getIncompletePayment({
  //   required String companyId,
  // }) async {
  //   try {
  //     final callable =
  //         _functions.httpsCallable('stripe_getIncompletePayment');
  //     final res = await callable.call(<String, dynamic>{
  //       'companyId': companyId,
  //     });

  //     final data = Map<String, dynamic>.from(res.data as Map);
  //     final model = StripeIncompletePaymentModel.fromJson(data);

  //     return Result(data: model, success: true);
  //   } on FirebaseFunctionsException catch (e) {
  //     print(e);
  //     return Result(
  //       data: null,
  //       success: false,
  //     );
  //   } catch (e) {
  //     return Result(
  //       data: null,
  //       success: false,
  //     );
  //   }
  // }

  // @override
  // Future<Result<StripeOpenInvoicePaymentModel?>> getOpenInvoicePayment({
  //   required String companyId,
  // }) async {
  //   try {
  //     final callable = _functions.httpsCallable('stripe_getOpenInvoicePayment');
  //     final res = await callable.call(<String, dynamic>{
  //       'companyId': companyId,
  //     });

  //     final data = Map<String, dynamic>.from(res.data as Map);
  //     final model = StripeOpenInvoicePaymentModel.fromJson(data);

  //     return Result(success: true, data: model);
  //   } on FirebaseFunctionsException catch (e) {
  //     final pretty = '${e.code}: ${e.message ?? ''}';
  //     return Result(success: false, data: null, errorCode: pretty);
  //   } catch (e) {
  //     return Result(success: false, data: null, errorCode: 'unknown: $e');
  //   }
  // }

  // @override
  // Future<Result<UpdateSeatsAndPayResult?>> updateSeatsAndPay({
  //   required String companyId,
  //   required int newTotalSeats,
  // }) async {
  //   try {
  //     final callable =
  //         _functions.httpsCallable('stripe_updateSeatsAndPay');

  //     final res = await callable.call({
  //       'companyId': companyId,
  //       'newTotalSeats': newTotalSeats,
  //     });

  //     final data = Map<String, dynamic>.from(res.data);

  //     return Result(
  //       data: UpdateSeatsAndPayResult.fromJson(data),
  //       success: true,
  //     );
  //   } on FirebaseFunctionsException catch (e) {
  //     return Result(
  //       data: null,
  //       success: false,
  //       errorCode: e.code,
  //     );
  //   } catch (e) {
  //     return Result(
  //       data: null,
  //       success: false,
  //       errorCode: 'unknown-error',
  //     );
  //   }
  // }

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
  Future<Result<PrepareSeatPaymentSheetResponse?>> prepareSeatPaymentSheet({
    required String companyId,
    required int newTotalSeats,
  }) async {
    try {
      final callable = _functions.httpsCallable('stripe_prepareSeatPaymentSheet');

      final resp = await callable.call(<String, dynamic>{
        'companyId': companyId,
        'newTotalSeats': newTotalSeats,
      });

      final data = Map<String, dynamic>.from(resp.data as Map);

      return Result(
        success: true,
        data: PrepareSeatPaymentSheetResponse.fromJson(data),
      );
    } on FirebaseFunctionsException catch (e) {
      return Result(
        data: null,
        success: false,
        errorCode: e.code,
      );
    } catch (e) {
      return Result(
        data: null,
        success: false,
        errorCode: 'unknown',
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
}