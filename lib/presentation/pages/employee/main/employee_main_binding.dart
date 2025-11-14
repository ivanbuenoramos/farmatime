import 'package:get/get.dart';

import 'package:farmatime/presentation/presentation.dart';
import 'package:farmatime/presentation/pages/chat/inbox/inbiox_binding.dart';
import 'package:farmatime/presentation/pages/employee/my_day/employee_may_day_binding.dart';
import 'package:farmatime/presentation/pages/employee/entries/employee_entries_binding.dart';



class EmployeeMainBinding extends Bindings {
  @override
  void dependencies() {
    
    EmployeeMyDayBinding().dependencies();
    EmployeeEntriesBinding().dependencies();
    InboxBinding().dependencies();
    EmployeeCalendarBinding().dependencies();
    EmployeeAccountBinding().dependencies();
    
    Get.lazyPut<EmployeeMainController>(() => EmployeeMainController());

  }
}