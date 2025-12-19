import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/usecases/employee/get_employees_by_company_id_usecase.dart';
import 'package:farmatime/domain/usecases/employee/update_employee_usecase.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';

class CompanyEmployeesController extends GetxController {
  final GetEmployeesByCompanyIdUseCase getEmployeesByCompanyIdUseCase;
  final UpdateEmployeeUseCase updateEmployeeUseCase;

  CompanyEmployeesController({
    required this.getEmployeesByCompanyIdUseCase,
    required this.updateEmployeeUseCase,
  });

  final Brain brain = Get.find<Brain>();

  final RxList<EmployeeModel> employees = <EmployeeModel>[].obs;

  /// plazas contratadas (Stripe) cuando la suscripción está bien
  final RxInt contractedSeats = 1.obs;

  final RxBool isLoading = false.obs;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _companySub;

  String get companyId => brain.company.value?.id ?? '';

  // ---------------------------
  //  ✅ NUEVO: billing gating
  // ---------------------------

  String get billingStatus => (brain.company.value?.billingStatus ?? 'none').toString();

  bool get subscriptionIsOk {
    return billingStatus == 'active' || billingStatus == 'none';
  }

  /// Plazas efectivas: si hay problema de pago => solo 1
  int get effectiveSeats => subscriptionIsOk ? contractedSeats.value : 1;

  /// ID del empleado más antiguo (según createdAt si existe; fallback estable)
  String? get oldestEmployeeId {
    if (employees.isEmpty) return null;

    // Intenta ordenar por createdAt si tu modelo lo tiene (DateTime o Timestamp o int).
    // Como no tengo tu EmployeeModel, lo hago defensivo.
    int safeMillis(EmployeeModel e) {
      try {
        final dynamic v = (e as dynamic).createdAt;
        if (v == null) return 0;
        if (v is DateTime) return v.millisecondsSinceEpoch;
        if (v is Timestamp) return v.millisecondsSinceEpoch;
        if (v is int) return v;
        if (v is String) {
          final dt = DateTime.tryParse(v);
          return dt?.millisecondsSinceEpoch ?? 0;
        }
      } catch (_) {}
      return 0;
    }

    final sorted = [...employees];
    sorted.sort((a, b) {
      final ma = safeMillis(a);
      final mb = safeMillis(b);
      if (ma != mb) return ma.compareTo(mb);

      // fallback: id para que sea determinista
      final ida = (a.uid).toString();
      final idb = (b.uid).toString();
      return ida.compareTo(idb);
    });

    return (sorted.first.uid).toString();
  }

  /// Solo el más antiguo puede “usar” la app si hay problema de pago
  bool canAccessEmployee(EmployeeModel employee) {
    if (subscriptionIsOk) return true;
    final oid = oldestEmployeeId;
    if (oid == null) return false;
    return (employee.uid).toString() == oid;
  }

  bool get canCreateEmployee {
    // Si hay problema de pago: no se puede crear NUNCA
    if (!subscriptionIsOk) return false;
    return employees.length < effectiveSeats;
  }

  @override
  void onInit() {
    super.onInit();

    contractedSeats.value = brain.company.value?.contractedSeats ?? 1;

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

        // Si tu Brain se actualiza por otro lado ok.
        // Si no, aquí también podrías actualizar brain.company.billingStatus, etc.
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

      final Result result = await getEmployeesByCompanyIdUseCase.call(
        companyId: companyId,
      );

      if (result.success) {
        final list = (result.data as List<EmployeeModel>)
            .where((e) => e.accountStatus != EmployeeAccountStatus.deleted)
            .toList();

        employees.value = list;

        // Evita duplicar si fetch se llama más veces
        brain.companyEmployees
          ..clear()
          ..addAll(list);

        // Orden “bonito”: activos primero, luego resto.
        employees.sort((a, b) => a.accountStatus!.index.compareTo(b.accountStatus!.index));
      } else {
        Get.snackbar('Error', 'No se pudieron cargar los empleados: ${result.errorCode}');
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to fetch employees: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// FAB o tarjeta vacía → crear empleado (si hay hueco), sino modal
  void onAddEmployeePressed() {
    if (!subscriptionIsOk) {
      // aquí puedes mandar a suscripción o mostrar modal específico
      reditectToSubscription();
      return;
    }

    if (canCreateEmployee) {
      reditectToUpsertEmployee();
    } else {
      _showNoSlotsModal(effectiveSeats);
    }
  }

  void onSubscriptionStatusBannerTapped() {
    Get.toNamed(Routes.companySubscription);
  }

  void _showNoSlotsModal(int employeesCount) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Get.theme.colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/icons/user_add.svg',
                      height: 120,
                      colorFilter: ColorFilter.mode(
                        Get.theme.colorScheme.primary,
                        BlendMode.srcIn,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Get.theme.colorScheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Get.theme.colorScheme.outline,
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 26,
                          color: Get.theme.colorScheme.tertiary,
                        ),
                      ),
                    )
                  ],
                ),
              ),
              Text('¡Ups!', style: Get.textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              if (employeesCount == 1)
                Text(
                  'Has alcanzado el límite de 1 empleado gratuito. Para añadir más empleados, por favor actualiza tu suscripción.',
                  style: Get.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                )
              else
                Text(
                  'Has alcanzado el límite de $employeesCount empleados para tu suscripción actual. Para añadir más empleados, por favor actualiza tu suscripción.',
                  style: Get.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Get.back();
                    reditectToSubscription();
                  },
                  child: const Text('Ir a suscripción'),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  void reditectToSubscription() {
    Get.toNamed(Routes.companySubscription);
  }

  void reditectToUpsertEmployee() {
    Get.toNamed(Routes.companyUpsertEmployee);
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