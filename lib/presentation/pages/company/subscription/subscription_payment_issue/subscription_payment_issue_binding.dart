import 'package:get/get.dart';

import 'package:farmatime/presentation/presentation.dart';
import 'package:farmatime/domain/repositories/stripe_repository.dart';
import 'package:farmatime/data/repositories/stripe_repository_impl.dart';
import 'package:farmatime/domain/usecases/stripe/create_setup_intent_usecase.dart';
import 'package:farmatime/domain/usecases/stripe/prepare_seat_change_payment_usecase.dart';



class SubscriptionPaymentIssueBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<StripeRepository>(() => StripeRepositoryImpl());

    Get.lazyPut<CreateSetupIntentUseCase>(
      () => CreateSetupIntentUseCase(Get.find<StripeRepository>()),
    );
    
    Get.lazyPut<PrepareSeatChangePaymentUseCase>(
      () => PrepareSeatChangePaymentUseCase(Get.find<StripeRepository>()),
    );

    Get.lazyPut<SubscriptionPaymentIssueController>(() => SubscriptionPaymentIssueController(
      setupIntentUseCase: Get.find<CreateSetupIntentUseCase>(),
      prepareSeatChangePaymentUseCase: Get.find<PrepareSeatChangePaymentUseCase>(),
    ));
  }
}