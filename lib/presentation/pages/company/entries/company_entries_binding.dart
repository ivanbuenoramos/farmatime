import 'package:farmatime/presentation/pages/company/entries/company_entries_controller.dart';
import 'package:get/get.dart';

class CompanyEntriesBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(CompanyEntriesController());
  }
}
