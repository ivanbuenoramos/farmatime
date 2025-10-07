import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/usecases/employee/get_employees_by_company_id_usecase.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';

class CompanyEmployeesController extends GetxController {
  final GetEmployeesByCompanyIdUseCase getEmployeesByCompanyIdUseCase;

  CompanyEmployeesController({
    required this.getEmployeesByCompanyIdUseCase,
  });

  final Brain brain = Get.find<Brain>();

  final RxList<EmployeeModel> employees = <EmployeeModel>[].obs;
  final RxInt contractedSeats = 1.obs; // plazas contratadas (Stripe)
  final RxBool isLoading = false.obs;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _companySub;

  String get companyId => brain.company.value?.id ?? '';

  /// ¿Quedan huecos para crear empleado?
  bool get canCreateEmployee => employees.length < contractedSeats.value;

  @override
  void onInit() {
    super.onInit();
    // valor inicial desde memoria
    contractedSeats.value = brain.company.value?.contractedSeats ?? 1;

    // escucha en vivo el doc de la empresa para actualizar plazas
    final id = companyId;
    if (id.isNotEmpty) {
      _companySub = FirebaseFirestore.instance
          .collection('companies')
          .doc(id)
          .snapshots()
          .listen((doc) {
        if (!doc.exists) return;
        final data = doc.data()!;
        final seats = data['contractedSeats'];
        if (seats is int) {
          contractedSeats.value = seats;
        } else if (seats != null) {
          final parsed = int.tryParse('$seats');
          if (parsed != null) contractedSeats.value = parsed;
        }
      });
    }

    fetchEmployees();
  }

  Future<void> fetchEmployees() async {
    if (companyId.isEmpty) {
      Get.snackbar('Error', 'Falta el ID de empresa');
      return;
    }
    try {
      isLoading.value = true;
      final Result result =
          await getEmployeesByCompanyIdUseCase.call(companyId);
      if (result.success) {
        employees.value = (result.data as List<EmployeeModel>);
      } else {
        Get.snackbar(
            'Error', 'No se pudieron cargar los empleados: ${result.errorCode}');
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to fetch employees: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// FAB o tarjeta vacía → crear empleado (si hay hueco), sino modal
  void onAddEmployeePressed() {
    if (canCreateEmployee) {
      reditectToCreateEmployee();
    } else {
      _showNoSlotsModal();
    }
  }

  void _showNoSlotsModal() {
    Get.defaultDialog(
      title: 'Sin huecos contratados',
      middleText:
          'Para crear un nuevo empleado necesitas contratar un espacio más.',
      textConfirm: 'Ir a suscripción',
      textCancel: 'Cancelar',
      onConfirm: () {
        Get.back();
        // Get.toNamed(Routes.subscription); // ajusta si tu ruta difiere
      },
      confirmTextColor: Colors.white,
    );
  }

  void reditectToCreateEmployee() {
    Get.toNamed(Routes.companyCreateEmployee);
  }

  void reditectToEmployeeDetail(EmployeeModel employee) {
    Get.toNamed(Routes.companyEmployeeDetail, arguments: employee);
  }

  @override
  void onClose() {
    _companySub?.cancel();
    super.onClose();
  }
}