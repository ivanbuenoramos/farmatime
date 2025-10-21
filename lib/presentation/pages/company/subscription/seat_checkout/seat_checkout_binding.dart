import 'package:get/get.dart';

import 'package:farmatime/domain/usecases/stripe/create_stripe_customer_and_subscription_usecase.dart';
import 'package:farmatime/domain/usecases/stripe/prepare_seat_change_payment_usecase.dart';
import 'seat_checkout_controller.dart';

class SeatCheckoutBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SeatCheckoutController>(() => SeatCheckoutController(
          createStripeCustomerAndSubscriptionUseCase:
              Get.find<CreateStripeCustomerAndSubscriptionUseCase>(),
          prepareSeatChangePaymentUseCase:
              Get.find<PrepareSeatChangePaymentUseCase>(),
        ));
  }
}