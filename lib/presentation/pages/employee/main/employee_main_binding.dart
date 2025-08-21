import 'package:farmatime/presentation/pages/employee/calendar/employee_calendar_binding.dart';
import 'package:farmatime/presentation/pages/employee/entries/employee_entries_binding.dart';
import 'package:farmatime/presentation/pages/employee/my_day/employee_may_day_binding.dart';
import 'package:farmatime/presentation/pages/employee/profile/employee_profile_binding.dart';
import 'package:get/get.dart';

import 'package:farmatime/presentation/pages/company/main/company_main_controller.dart';



class EmployeeMainBinding extends Bindings {
  @override
  void dependencies() {
    
    EmployeeMyDayBinding().dependencies();
    EmployeeEntriesBinding().dependencies();
    EmployeeCalendarBinding().dependencies();
    EmployeeProfileBinding().dependencies();
    
    Get.lazyPut<CompanyMainController>(() => CompanyMainController());

  }
}