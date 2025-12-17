import 'package:farmatime/data/repositories/stripe_repository_impl.dart';
import 'package:farmatime/domain/repositories/stripe_repository.dart';
import 'package:farmatime/domain/usecases/stripe/prepare_seat_payment_sheet_usecase.dart';
import 'package:get/get.dart';

import 'seat_checkout_controller.dart';
import 'package:farmatime/domain/repositories/employee_repository.dart';
import 'package:farmatime/data/repositories/employee_repository_impl.dart';



class SeatCheckoutBinding extends Bindings {
  @override
  void dependencies() {

    Get.lazyPut<EmployeeRepository>(() => EmployeeRepositoryImpl());
    Get.lazyPut<StripeRepository>(() => StripeRepositoryImpl());

    Get.lazyPut<PrepareSeatPaymentSheetUseCase>(
      () => PrepareSeatPaymentSheetUseCase(Get.find<StripeRepository>()),
    );

    Get.lazyPut<SeatCheckoutController>(() => SeatCheckoutController(
      prepareSeatPaymentSheetUseCase: Get.find<PrepareSeatPaymentSheetUseCase>(),
    ));
  }
}