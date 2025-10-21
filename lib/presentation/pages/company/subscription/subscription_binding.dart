import 'package:get/get.dart';

import 'package:farmatime/domain/repositories/stripe_repository.dart';
import 'package:farmatime/data/repositories/stripe_repository_impl.dart';
import 'package:farmatime/domain/usecases/stripe/list_invoices_usecase.dart';
import 'package:farmatime/domain/usecases/stripe/prepare_seat_change_payment_usecase.dart';
import 'package:farmatime/domain/usecases/stripe/update_subscription_quantity_usecase.dart';
import 'package:farmatime/domain/usecases/stripe/create_billing_portal_session_usecase.dart';
import 'package:farmatime/presentation/pages/company/subscription/subscription_controller.dart';
import 'package:farmatime/domain/usecases/stripe/create_stripe_customer_and_subscription_usecase.dart';



class SubscriptionBinding extends Bindings {
  @override
  void dependencies() {
    
    Get.lazyPut<StripeRepository>(() => StripeRepositoryImpl());

    Get.lazyPut<UpdateSubscriptionQuantityUseCase>(
      () => UpdateSubscriptionQuantityUseCase(Get.find<StripeRepository>()),
    );

    Get.lazyPut<CreateBillingPortalSessionUseCase>(
      () => CreateBillingPortalSessionUseCase(Get.find<StripeRepository>()),
    );

    Get.lazyPut<CreateStripeCustomerAndSubscriptionUseCase>(
      () => CreateStripeCustomerAndSubscriptionUseCase(Get.find<StripeRepository>()),
    );

    Get.lazyPut<ListInvoicesUseCase>(
      () => ListInvoicesUseCase(Get.find<StripeRepository>()),
    );

    Get.lazyPut<PrepareSeatChangePaymentUseCase>(
      () => PrepareSeatChangePaymentUseCase(Get.find<StripeRepository>()),
    );

    Get.lazyPut<SubscriptionController>(() => SubscriptionController(
      updateSubscriptionQuantityUseCase: Get.find<UpdateSubscriptionQuantityUseCase>(),
      createBillingPortalSessionUseCase: Get.find<CreateBillingPortalSessionUseCase>(),
      createStripeCustomerAndSubscriptionUseCase: Get.find<CreateStripeCustomerAndSubscriptionUseCase>(),
      listInvoicesUseCase: Get.find<ListInvoicesUseCase>(),
      prepareSeatChangePaymentUseCase: Get.find<PrepareSeatChangePaymentUseCase>(),
    ));
  }
}