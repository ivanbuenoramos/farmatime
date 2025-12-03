import 'package:farmatime/presentation/pages/company/subscription/select_employee_to_remove/select_employee_to_remove_binding.dart';
import 'package:farmatime/presentation/pages/company/subscription/select_employee_to_remove/select_employees_to_remove_page.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/usecases/employee/get_employees_by_company_id_usecase.dart';

import 'package:farmatime/domain/usecases/stripe/prepare_seat_change_payment_usecase.dart';
import 'package:farmatime/presentation/pages/company/subscription/confirm_seat_change/confirm_seat_change_page.dart';
import 'package:farmatime/presentation/pages/company/subscription/confirm_seat_change/confirm_seat_change_binding.dart';

enum SeatPayMethod { nativePay, card }

class SeatEmployee {
  final String id;
  final String name;
  final String? email;

  const SeatEmployee({
    required this.id,
    required this.name,
    this.email,
  });
}

class SeatCheckoutController extends GetxController {
  SeatCheckoutController({
    required this.prepareSeatChangePaymentUseCase,
    required this.getEmployeesByCompanyIdUseCase,
  });

  final PrepareSeatChangePaymentUseCase prepareSeatChangePaymentUseCase;
  final GetEmployeesByCompanyIdUseCase getEmployeesByCompanyIdUseCase;

  final Brain brain = Get.find<Brain>();

  final RxInt seats = 1.obs;
  final RxBool loading = false.obs;
  final RxString error = ''.obs;

  /// IDs de empleados que se van a desactivar al reducir plazas
  final RxList<String> employeesToDeactivate = <String>[].obs;

  String get companyId => brain.company.value?.id ?? '';
  int get contractedSeatsNow => brain.company.value?.contractedSeats ?? 1;

  bool get hasStripeSetup =>
      (brain.company.value?.stripeCustomerId ?? '').isNotEmpty &&
      (brain.company.value?.stripeSubscriptionId ?? '').isNotEmpty;

  bool get isCompanyAccount {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null && uid == companyId;
  }

  /// 1ª plaza gratis, resto 1€/mes
  int get monthlyCents => (seats.value > 1) ? (seats.value - 1) * 100 : 0;

  bool get hasChanges {
    final current = contractedSeatsNow <= 0 ? 1 : contractedSeatsNow;
    return seats.value != current;
  }

  @override
  void onInit() {
    super.onInit();
    final init = contractedSeatsNow <= 0 ? 1 : contractedSeatsNow;
    seats.value = init;
  }

  void inc() => seats.value = seats.value + 1;
  void dec() => seats.value = seats.value <= 1 ? 1 : seats.value - 1;

  Future<void> onContinue(BuildContext context) async {
    if (companyId.isEmpty) {
      Get.snackbar('Error', 'Empresa no encontrada');
      return;
    }
    if (!isCompanyAccount) {
      Get.snackbar('Permisos', 'Solo la cuenta de empresa puede actualizar plazas.');
      return;
    }
    if (!hasChanges) {
      Get.snackbar('Sin cambios', 'No has modificado las plazas.');
      return;
    }

    final current = contractedSeatsNow <= 0 ? 1 : contractedSeatsNow;
    final newSeats = seats.value;

    // 🔹 Si reducimos plazas, miramos si hay que elegir empleados a eliminar
    if (newSeats < current) {
      final ok = await _ensureEmployeesSelectionForReduction(
        currentSeats: current,
        newSeats: newSeats,
      );

      if (!ok) {
        // Usuario canceló o no completó la selección
        return;
      }
    } else {
      // Si no reducimos, nos aseguramos de limpiar
      employeesToDeactivate.clear();
    }

    // CASO A: NO hay suscripción Stripe -> flujo de alta inicial (tu otra pantalla)
    if (!hasStripeSetup) {
      Get.toNamed(
        '/subscription/checkout',
        arguments: {
          'initialSeats': newSeats,
          // Si quieres, también puedes pasar aquí employeesToDeactivate
        },
      );
      return;
    }

    // CASO B: Ya hay suscripción -> pantalla de confirmación
    final result = await Get.to<bool>(
      () => ConfirmSeatChangePage(
        initialSeats: current,
        newSeats: newSeats,
        // Desde esta página puedes leer Get.find<SeatCheckoutController>()
        // y usar employeesToDeactivate si hace falta mandarlo a la Cloud Function.
      ),
      binding: ConfirmSeatChangeBinding(
        prepareSeatChangePaymentUseCase: prepareSeatChangePaymentUseCase,
      ),
      arguments: {
        'initialSeats': current,
        'newSeats': newSeats,
      },
    );

    // ⬇️ SI EL USUARIO NO CONFIRMA, VOLVEMOS AL PLAN REAL
    if (result != true) {
      final realSeats = contractedSeatsNow <= 0 ? 1 : contractedSeatsNow;
      seats.value = realSeats;
      employeesToDeactivate.clear();
    }
  }

  /// Carga los empleados activos y obliga a seleccionar a quién se desactiva
  Future<bool> _ensureEmployeesSelectionForReduction({
    required int currentSeats,
    required int newSeats,
  }) async {
    // Obtenemos los empleados activos para saber si hay más empleados que plazas nuevas
    final List<SeatEmployee> activeEmployees = await _getActiveSeatEmployees();

    if (activeEmployees.isEmpty) {
      // Sin empleados, nada que seleccionar.
      employeesToDeactivate.clear();
      return true;
    }

    final activeCount = activeEmployees.length;

    // Si el nº de empleados activos ya es <= a las nuevas plazas, no hace falta echar a nadie
    if (activeCount <= newSeats) {
      employeesToDeactivate.clear();
      return true;
    }

    final mustRemove = activeCount - newSeats;

    final selectedIds = await Get.to<List<String>>(
      () => const SelectEmployeeToRemovePage(),
      binding: SelectEmployeeToRemoveBinding(),
      arguments: {
        'mustRemove': mustRemove,
        'seatsAfterChange': newSeats,
      },
    );

    if (selectedIds == null) {
      // Usuario canceló
      return false;
    }

    if (selectedIds.length != mustRemove) {
      Get.snackbar(
        'Selección incompleta',
        'Debes seleccionar exactamente $mustRemove empleado(s).',
      );
      return false;
    }

    employeesToDeactivate
      ..clear()
      ..addAll(selectedIds);

    return true;
  }

  /// Usa el usecase para traer empleados activos de la empresa
  Future<List<SeatEmployee>> _getActiveSeatEmployees() async {
    if (companyId.isEmpty) {
      return <SeatEmployee>[];
    }

    final Result<List<EmployeeModel>> res =
        await getEmployeesByCompanyIdUseCase.call(companyId);

    if (!res.success) {
      error.value = 'No se pudieron cargar los empleados';
      Get.snackbar('Error', error.value);
      return <SeatEmployee>[];
    }

    final list = res.data;

    return list
        .where((e) => e.accountStatus != EmployeeAccountStatus.deleted)
        .map((e) => SeatEmployee(
              id: e.uid,
              name: e.name,
              email: e.email,
            ))
        .where((e) => e.id.isNotEmpty)
        .toList();
  }
}