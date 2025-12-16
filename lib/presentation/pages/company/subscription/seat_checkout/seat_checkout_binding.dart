import 'package:farmatime/data/repositories/stripe_repository_impl.dart';
import 'package:farmatime/domain/repositories/stripe_repository.dart';
import 'package:farmatime/domain/usecases/stripe/create_stripe_customer_and_subscription_usecase.dart';
import 'package:farmatime/domain/usecases/stripe/update_seats_and_pay_usecase.dart';
import 'package:get/get.dart';

import 'seat_checkout_controller.dart';
import 'package:farmatime/domain/repositories/employee_repository.dart';
import 'package:farmatime/data/repositories/employee_repository_impl.dart';
import 'package:farmatime/domain/usecases/employee/get_employees_by_company_id_usecase.dart';



class SeatCheckoutBinding extends Bindings {
  @override
  void dependencies() {

    Get.lazyPut<EmployeeRepository>(() => EmployeeRepositoryImpl());
    Get.lazyPut<StripeRepository>(() => StripeRepositoryImpl());
  
    Get.lazyPut<GetEmployeesByCompanyIdUseCase>(
      () => GetEmployeesByCompanyIdUseCase(Get.find<EmployeeRepository>()),
    );
    Get.lazyPut<CreateStripeCustomerAndSubscriptionUseCase>(
      () => CreateStripeCustomerAndSubscriptionUseCase(Get.find<StripeRepository>()),
    );
    Get.lazyPut<UpdateSeatsAndPayUseCase>(
      () => UpdateSeatsAndPayUseCase(Get.find<StripeRepository>()),
    );

    Get.lazyPut<SeatCheckoutController>(() => SeatCheckoutController(
      updateSeatsAndPayUseCase: Get.find<UpdateSeatsAndPayUseCase>(),
      // getEmployeesByCompanyIdUseCase: Get.find<GetEmployeesByCompanyIdUseCase>(),
      // createCustomerAndSubscriptionUseCase: Get.find<CreateStripeCustomerAndSubscriptionUseCase>(),
    ));
  }
}