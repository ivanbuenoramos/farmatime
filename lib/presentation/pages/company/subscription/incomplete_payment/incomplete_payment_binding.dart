import 'package:farmatime/data/repositories/stripe_repository_impl.dart';
import 'package:get/get.dart';

import 'package:farmatime/domain/repositories/stripe_repository.dart';
import 'package:farmatime/domain/usecases/stripe/get_incomplete_payment_usecase.dart';
import 'package:farmatime/presentation/pages/company/subscription/incomplete_payment/incomplete_payment_controller.dart';

class IncompletePaymentBinding extends Bindings {
  @override
  void dependencies() {

    Get.lazyPut<StripeRepository>(() => StripeRepositoryImpl());

    Get.lazyPut<GetIncompletePaymentUseCase>(
      () => GetIncompletePaymentUseCase(Get.find<StripeRepository>())
    );

    Get.lazyPut<IncompletePaymentController>(
      () => IncompletePaymentController(
        getIncompletePaymentUseCase: Get.find<GetIncompletePaymentUseCase>(),
      ),
    );
  }
}