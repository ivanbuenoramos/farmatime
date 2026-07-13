import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/core/services/toast_service.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/domain/usecases/employee/get_employees_by_company_id_usecase.dart';
import 'package:farmatime/domain/usecases/employee/update_employee_usecase.dart';
import 'package:farmatime/domain/usecases/employee/stream_employees_by_company_id_usecase.dart';
import 'package:farmatime/data/models/schedule/time_off_model.dart';
import 'package:farmatime/domain/usecases/time_off/stream_time_off_by_company_usecase.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';

class CompanyEmployeesController extends GetxController {
  final GetEmployeesByCompanyIdUseCase getEmployeesByCompanyIdUseCase;
  final UpdateEmployeeUseCase updateEmployeeUseCase;

  // ✅ nuevo
  final StreamEmployeesByCompanyIdUseCase streamEmployeesByCompanyIdUseCase;

  // Solicitudes de ausencia (para el contador de pendientes)
  final StreamTimeOffByCompanyUseCase streamTimeOffByCompanyUseCase;

  CompanyEmployeesController({
    required this.getEmployeesByCompanyIdUseCase,
    required this.updateEmployeeUseCase,
    required this.streamEmployeesByCompanyIdUseCase,
    required this.streamTimeOffByCompanyUseCase,
  });

  final Brain brain = Get.find<Brain>();

  final RxList<EmployeeModel> employees = <EmployeeModel>[].obs;

  /// plazas contratadas (incluye la plaza gratuita)
  final RxInt contractedSeats = 1.obs;

  final RxBool isLoading = false.obs;

  /// Solicitudes de ausencia pendientes de respuesta de la empresa.
  final RxInt pendingTimeOff = 0.obs;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _companySub;

  // ✅ nuevo
  StreamSubscription<List<EmployeeModel>>? _employeesSub;

  StreamSubscription<List<TimeOffModel>>? _timeOffSub;

  String get companyId => brain.company.value?.id ?? '';

  // ---------------------------
  //  ✅ billing gating
  // ---------------------------

  String get billingStatus => (brain.company.value?.billingStatus ?? 'none').toString();

  bool get subscriptionIsOk => billingStatus == 'active' || billingStatus == 'none';

  int get effectiveSeats => subscriptionIsOk ? contractedSeats.value : 1;

  String? get oldestEmployeeId {
    if (employees.isEmpty) return null;

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
      return a.uid.toString().compareTo(b.uid.toString());
    });

    return sorted.first.uid.toString();
  }

  bool canAccessEmployee(EmployeeModel employee) {
    if (subscriptionIsOk) return true;
    final oid = oldestEmployeeId;
    if (oid == null) return false;
    return employee.uid.toString() == oid;
  }

  bool get canCreateEmployee {
    if (!subscriptionIsOk) return false;
    return employees.length < effectiveSeats;
  }

  @override
  void onInit() {
    super.onInit();

    contractedSeats.value = brain.company.value?.contractedSeats ?? 1;

    final id = companyId;
    if (id.isEmpty) {
      ToastService().show(title: 'Error', message: 'Falta el ID de empresa', type: ToastType.error);
      return;
    }

    // Listener seats/empresa (tu código)
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

    // ✅ Listener empleados (single source of truth para toda la app)
    _employeesSub = streamEmployeesByCompanyIdUseCase(companyId: id).listen((list) {
      // filtra soft-delete si lo necesitas aquí (o en el repo)
      final filtered = list
          .where((e) => e.accountStatus != EmployeeAccountStatus.deleted)
          .toList();

      // orden “bonito” (toleramos accountStatus null al final)
      const lastIdx = 1 << 30;
      filtered.sort((a, b) {
        final ai = a.accountStatus?.index ?? lastIdx;
        final bi = b.accountStatus?.index ?? lastIdx;
        return ai.compareTo(bi);
      });

      employees.value = filtered;

      // ✅ global para el resto de pantallas
      brain.companyEmployees
        ..clear()
        ..addAll(filtered);
    }, onError: (e) {
      debugPrint('Stream empleados error: $e');
      ToastService().show(title: 'Error', message: 'No se pudieron cargar los empleados. Inténtalo de nuevo.', type: ToastType.error);
    });

    // ✅ Listener solicitudes de ausencia (contador de pendientes)
    _timeOffSub = streamTimeOffByCompanyUseCase(companyId: id).listen((list) {
      pendingTimeOff.value = list.where((r) => r.awaitingCompany).length;
    }, onError: (_) {
      // El contador es informativo; no rompemos la UI si falla.
    });

    // Si quieres mantener también la carga inicial por fetch (opcional):
    // fetchEmployees();
  }

  // Puedes dejar fetchEmployees() si te sirve para “forzar refresh” manual,
  // pero ya NO es necesaria para mantener el estado global.

  void onAddEmployeePressed() {
    if (!subscriptionIsOk) {
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
              Text(
                employeesCount == 1
                    ? 'Has alcanzado el límite de 1 empleado gratuito. Para añadir más empleados, por favor actualiza tu suscripción.'
                    : 'Has alcanzado el límite de $employeesCount empleados para tu suscripción actual. Para añadir más empleados, por favor actualiza tu suscripción.',
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

  void reditectToSubscription() => Get.toNamed(Routes.companySubscription);
  void reditectToUpsertEmployee() => Get.toNamed(Routes.companyUpsertEmployee);
  void reditectToEmployeeDetail(EmployeeModel employee) =>
      Get.toNamed(Routes.companyEmployeeDetail, arguments: employee);
  void redirectToTimeOff() => Get.toNamed(Routes.companyTimeOff);

  @override
  void onClose() {
    _companySub?.cancel();
    _employeesSub?.cancel(); // ✅ importante
    _timeOffSub?.cancel();
    super.onClose();
  }
}