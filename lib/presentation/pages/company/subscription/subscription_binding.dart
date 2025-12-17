import 'package:farmatime/domain/usecases/stripe/create_stripe_customer_usecase.dart';
import 'package:get/get.dart';

import 'package:farmatime/domain/repositories/stripe_repository.dart';
import 'package:farmatime/data/repositories/stripe_repository_impl.dart';
import 'package:farmatime/domain/usecases/stripe/list_invoices_usecase.dart';
import 'package:farmatime/presentation/pages/company/subscription/subscription_controller.dart';



class SubscriptionBinding extends Bindings {
  @override
  void dependencies() {
    
    Get.lazyPut<StripeRepository>(() => StripeRepositoryImpl());

    Get.lazyPut<ListInvoicesUseCase>(
      () => ListInvoicesUseCase(Get.find<StripeRepository>()),
    );

    Get.lazyPut<CreateStripeCustomerUseCase>(
      () => CreateStripeCustomerUseCase(Get.find<StripeRepository>()),
    );

    Get.lazyPut<SubscriptionController>(() => SubscriptionController(
      listInvoicesUseCase: Get.find<ListInvoicesUseCase>(),
      createStripeCustomerUseCase: Get.find<CreateStripeCustomerUseCase>(),
    ));
  }
}