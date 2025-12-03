import 'package:get/get.dart';

import 'seat_checkout_controller.dart';
import 'package:farmatime/domain/repositories/employee_repository.dart';
import 'package:farmatime/data/repositories/employee_repository_impl.dart';
import 'package:farmatime/domain/usecases/stripe/prepare_seat_change_payment_usecase.dart';
import 'package:farmatime/domain/usecases/employee/get_employees_by_company_id_usecase.dart';



class SeatCheckoutBinding extends Bindings {
  @override
  void dependencies() {

    Get.lazyPut<EmployeeRepository>(() => EmployeeRepositoryImpl());
  

    Get.lazyPut<GetEmployeesByCompanyIdUseCase>(
      () => GetEmployeesByCompanyIdUseCase(Get.find<EmployeeRepository>()),
    );

    Get.lazyPut<SeatCheckoutController>(() => SeatCheckoutController(
      prepareSeatChangePaymentUseCase: Get.find<PrepareSeatChangePaymentUseCase>(),
      getEmployeesByCompanyIdUseCase: Get.find<GetEmployeesByCompanyIdUseCase>(),
    ));
  }
}