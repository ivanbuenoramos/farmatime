import 'package:farmatime/presentation/pages/company/entries/company_entries_controller.dart';
import 'package:get/get.dart';

class CompanyEntriesBinding extends Bindings {
  @override
  void dependencies() {
    // companyId puede llegar por arguments o por parámetros de ruta
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    final companyId = args['companyId'] ?? Get.parameters['companyId'];

    Get.put(CompanyEntriesController());
  }
}
