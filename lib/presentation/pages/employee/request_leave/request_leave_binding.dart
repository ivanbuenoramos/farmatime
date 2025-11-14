import 'package:get/get.dart';
import 'request_leave_controller.dart';

class RequestLeaveBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<RequestLeaveController>(() => RequestLeaveController());
  }
}