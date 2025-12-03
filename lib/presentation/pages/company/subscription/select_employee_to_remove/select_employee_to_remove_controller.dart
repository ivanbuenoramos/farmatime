import 'package:get/get.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/domain/usecases/employee/update_employee_usecase.dart';
import 'package:farmatime/domain/usecases/employee/get_employees_by_company_id_usecase.dart';



class SelectEmployeeToRemoveController extends GetxController {
  SelectEmployeeToRemoveController({
    required this.getEmployeesByCompanyIdUseCase,
    required this.updateEmployeeUseCase,
  });

  final GetEmployeesByCompanyIdUseCase getEmployeesByCompanyIdUseCase;
  final UpdateEmployeeUseCase updateEmployeeUseCase;
  final Brain brain = Get.find<Brain>();

  /// Datos recibidos por argumentos
  late final int seatsAfterChange;
  late final int mustRemove;

  /// Empleados activos reales, cargados desde Firestore
  final RxList<EmployeeModel> employees = <EmployeeModel>[].obs;

  /// Seleccionados
  final RxSet<String> selectedIds = <String>{}.obs;

  final RxBool loading = false.obs;
  final RxString error = ''.obs;

  String get companyId => brain.company.value?.id ?? '';
  bool get isValid => selectedIds.length == mustRemove;

  @override
  void onInit() {
    super.onInit();

    final args = Get.arguments as Map<String, dynamic>? ?? {};
    seatsAfterChange = args['seatsAfterChange'] as int? ?? 0;
    mustRemove = args['mustRemove'] as int? ?? 0;

    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    if (companyId.isEmpty) {
      error.value = 'Empresa no encontrada';
      Get.snackbar('Error', 'Empresa no encontrada');
      return;
    }

    loading.value = true;

    final res = await getEmployeesByCompanyIdUseCase.call(companyId);

    loading.value = false;

    if (!res.success) {
      error.value = 'Error al cargar empleados';
      Get.snackbar('Error', error.value);
      return;
    }

    final list = res.data;

    employees.assignAll(
      list.where((e) => e.accountStatus != EmployeeAccountStatus.deleted),
    );
  }

  void toggleSelect(String id) {
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
    } else {
      if (selectedIds.length >= mustRemove) return;
      selectedIds.add(id);
    }
  }

  Future<void> confirm() async {
    if (!isValid) {
      Get.snackbar(
        'Selección incompleta',
        'Debes seleccionar exactamente $mustRemove empleado(s).',
      );
      return;
    }

    loading.value = true;

    for (final empId in selectedIds) {
      final emp = employees.firstWhere((e) => e.uid == empId);

      final updated = emp.copyWith(accountStatus: EmployeeAccountStatus.deleted);
      final updateRes = await updateEmployeeUseCase.call(updated);

      if (!updateRes.success) {
        loading.value = false;
        Get.snackbar('Error', 'Error al actualizar empleado');
        return;
      }
    }

    loading.value = false;
    Get.back(result: selectedIds.toList());
  }
}