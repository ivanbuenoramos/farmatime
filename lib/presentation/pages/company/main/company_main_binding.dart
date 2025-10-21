import 'package:get/get.dart';

import 'package:farmatime/presentation/presentation.dart';
import 'package:farmatime/presentation/pages/chat/inbox/inbiox_binding.dart';
import 'package:farmatime/presentation/pages/company/entries/company_entries_binding.dart';
import 'package:farmatime/presentation/pages/company/employees/company_employees_binding.dart';
import 'package:farmatime/presentation/pages/company/dashboard/company_dashboard_binding.dart';


class CompanyMainBinding extends Bindings {
  @override
  void dependencies() {
    
    CompanyDashboardBinding().dependencies();
    CompanyEntriesBinding().dependencies();
    InboxBinding().dependencies();
    CompanyEmployeesBinding().dependencies();
    CompanyAccountBinding().dependencies();
    
    Get.lazyPut<CompanyMainController>(() => CompanyMainController());

  }
}