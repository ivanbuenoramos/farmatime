import 'package:get/get.dart';

import 'package:farmatime/core/app/brain.dart';



class DependencyInjection {
  static void init() {

    Get.lazyPut(() => Brain());

    final Brain brain = Get.find<Brain>();

    if (brain.employee.value != null) {

    } else if (brain.company.value != null) {

    } else {
      
    }

    
  }
}