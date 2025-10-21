//crea el binding

import 'package:farmatime/data/repositories/stripe_repository_impl.dart';
import 'package:farmatime/domain/repositories/stripe_repository.dart';
import 'package:get/get.dart';
import 'package:farmatime/domain/usecases/stripe/create_setup_intent_usecase.dart';
import 'package:farmatime/domain/usecases/stripe/detach_payment_method_usecase.dart';
import 'package:farmatime/domain/usecases/stripe/list_payment_methods_usecase.dart';
import 'package:farmatime/domain/usecases/stripe/set_default_payment_method_usecase.dart';
import 'package:farmatime/presentation/pages/company/payment_metods/list/payment_methods_controller.dart';

class PaymentMethodsBinding extends Bindings {
  @override
  void dependencies() {

    Get.lazyPut<StripeRepository>(() => StripeRepositoryImpl());

    Get.lazyPut<ListPaymentMethodsUseCase>(() => ListPaymentMethodsUseCase(Get.find<StripeRepository>()));
    Get.lazyPut<SetDefaultPaymentMethodUseCase>(() => SetDefaultPaymentMethodUseCase(Get.find<StripeRepository>()));
    Get.lazyPut<DetachPaymentMethodUseCase>(() => DetachPaymentMethodUseCase(Get.find<StripeRepository>()));
    Get.lazyPut<CreateSetupIntentUseCase>(() => CreateSetupIntentUseCase(Get.find<StripeRepository>()));
    
    Get.lazyPut<PaymentMethodsController>(() => PaymentMethodsController(
          listPaymentMethodsUseCase: Get.find<ListPaymentMethodsUseCase>(),
          setDefaultPaymentMethodUseCase: Get.find<SetDefaultPaymentMethodUseCase>(),
          detachPaymentMethodUseCase: Get.find<DetachPaymentMethodUseCase>(),
          createSetupIntentUseCase: Get.find<CreateSetupIntentUseCase>(),
        ));
  }
}