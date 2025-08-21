import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/usecases/employee/get_employees_by_company_id_usecase.dart';
import 'package:get/get.dart';



class CompanyEmployeesController extends GetxController {

  final GetEmployeesByCompanyIdUseCase getEmployeesByCompanyIdUseCase;

  CompanyEmployeesController({
    required this.getEmployeesByCompanyIdUseCase,
  });

  final Brain brain = Get.find<Brain>();

  final RxList<EmployeeModel> employees = <EmployeeModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchEmployees();
  }

  Future<void> fetchEmployees() async {
    try {
      if (brain.company.value != null) {
        final Result result = await getEmployeesByCompanyIdUseCase.call(brain.company.value!.id);

        if (result.success) {
          employees.value = result.data as List<EmployeeModel>;
        } else {
          Get.snackbar('Error', 'No se pudieron cargar los empleados: ${result.errorCode}');
        }

      } else {
        throw Exception('Company ID is required');
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to fetch employees: $e');
    }
  }

  void reditectToCreateEmployee() {
    Get.toNamed(Routes.companyCreateEmployee);
  }

  void reditectToEmployeeDetail(EmployeeModel employee) {
    Get.toNamed(Routes.companyEmployeeDetail, arguments: employee);
  }
}

