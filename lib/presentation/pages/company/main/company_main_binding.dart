import 'package:farmatime/data/repositories/employee_repository_impl.dart';
import 'package:farmatime/domain/repositories/employee_repository.dart';
import 'package:farmatime/domain/usecases/employee/get_employees_by_company_id_usecase.dart';
import 'package:get/get.dart';

import 'package:farmatime/presentation/presentation.dart';
import 'package:farmatime/presentation/pages/chat/inbox/inbiox_binding.dart';
import 'package:farmatime/presentation/pages/company/entries/company_entries_binding.dart';
import 'package:farmatime/presentation/pages/company/employees/company_employees_binding.dart';
import 'package:farmatime/presentation/pages/company/dashboard/company_dashboard_binding.dart';


class CompanyMainBinding extends Bindings {
  @override
  void dependencies() {
    
    CompanyEmployeesBinding().dependencies();
    CompanyDashboardBinding().dependencies();
    CompanyEntriesBinding().dependencies();
    InboxBinding().dependencies();
    CompanyAccountBinding().dependencies();

    Get.lazyPut<EmployeeRepository>(() => EmployeeRepositoryImpl());

    Get.lazyPut<GetEmployeesByCompanyIdUseCase>(
      () => GetEmployeesByCompanyIdUseCase(Get.find<EmployeeRepository>()),
    );
    
    Get.lazyPut<CompanyMainController>(() => CompanyMainController(
      getEmployeesByCompanyIdUseCase: Get.find<GetEmployeesByCompanyIdUseCase>(),
    ));

  }
}