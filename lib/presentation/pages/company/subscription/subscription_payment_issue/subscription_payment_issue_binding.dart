import 'package:farmatime/domain/usecases/stripe/get_open_invoice_payment_usecase.dart';
import 'package:get/get.dart';

import 'package:farmatime/presentation/presentation.dart';
import 'package:farmatime/domain/repositories/stripe_repository.dart';
import 'package:farmatime/data/repositories/stripe_repository_impl.dart';
import 'package:farmatime/domain/usecases/stripe/create_setup_intent_usecase.dart';



class SubscriptionPaymentIssueBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<StripeRepository>(() => StripeRepositoryImpl());

    Get.lazyPut<CreateSetupIntentUseCase>(
      () => CreateSetupIntentUseCase(Get.find<StripeRepository>()),
    );
    
    Get.lazyPut<GetOpenInvoicePaymentUseCase>(
      () => GetOpenInvoicePaymentUseCase(Get.find<StripeRepository>()),
    );

    Get.lazyPut<SubscriptionPaymentIssueController>(() => SubscriptionPaymentIssueController(
      setupIntentUseCase: Get.find<CreateSetupIntentUseCase>(),
      getOpenInvoicePaymentUseCase: Get.find<GetOpenInvoicePaymentUseCase>(),
    ));
  }
}