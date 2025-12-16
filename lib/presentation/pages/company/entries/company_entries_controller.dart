import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/presentation/widgets/modals/day_clockings_modal.dart';
import 'package:farmatime/domain/usecases/clock/get_company_clock_records_usecase.dart';
import 'package:farmatime/domain/usecases/employee/get_employees_by_company_id_usecase.dart';
import 'package:farmatime/domain/usecases/clock/get_employee_day_clock_records_usecase.dart';



// class EmployeeOption {
//   final String id;
//   final String name;
//   final EmployeeAccountStatus status;

//   EmployeeOption({required this.id, required this.name});
// }

class ClockRowView {
  final DateTime day;
  final String employeeName;
  final String rangeText;
  final int workedMinutes;
  final int expectedMinutes;

  int get diffMinutes => workedMinutes - expectedMinutes;

  String get workedHhMm =>
      "${(workedMinutes ~/ 60)}:${(workedMinutes % 60).toString().padLeft(2, '0')}";

  String get expectedHhMm =>
      "${(expectedMinutes ~/ 60)}h${expectedMinutes % 60 == 0 ? '' : ' ${(expectedMinutes % 60)} min'}";

  String get diffSigned =>
      "${diffMinutes >= 0 ? '+' : '-'}"
      "${diffMinutes.abs() ~/ 60 > 0 ? '${diffMinutes.abs() ~/ 60}h ' : ''}"
      "${(diffMinutes.abs() % 60)}m";

  ClockRowView({
    required this.day,
    required this.employeeName,
    required this.rangeText,
    required this.workedMinutes,
    required this.expectedMinutes,
  });
}

class CompanyEntriesController extends GetxController {
  final Brain brain = Get.find<Brain>();

  final GetCompanyClockRecordsUseCase getCompanyClockRecordsUseCase;
  final GetEmployeeDayClockRecordsUseCase getEmployeeDayClockRecordsUseCase;
  final GetEmployeesByCompanyIdUseCase getEmployeesByCompanyIdUseCase;

  CompanyEntriesController({
    required this.getCompanyClockRecordsUseCase,
    required this.getEmployeeDayClockRecordsUseCase,
    required this.getEmployeesByCompanyIdUseCase,
  });

  // Filtros
  final Rx<DateTime> from = Rx<DateTime>(_todayStart());
  final Rx<DateTime> to = Rx<DateTime>(_todayEnd());
  final RxnString selectedEmployeeId = RxnString(null); // null = "Todos"

  // Datos soporte
  final List<EmployeeModel> employees = <EmployeeModel>[].obs;

  // Tabla
  final rows = <ClockRowView>[].obs;
  final isLoading = false.obs;
  final errorText = RxnString();

  // Config
  final int expectedDailyMinutes = 480; // 8h

  bool get isBillingActive =>
      (brain.company.value?.billingStatus ?? 'active') == 'active';

  static DateTime _todayStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 0, 0, 0);
  }

  static DateTime _todayEnd() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  }

  @override
  void onInit() {
    super.onInit();
    _loadEmployees().then((_) => fetchRecords());
  }

  Future<void> setRange(DateTime start, DateTime end) async {
    if (end.difference(start).inDays > 31) {
      errorText.value = 'El rango máximo es de 1 mes.';
      return;
    }
    from.value = DateTime(start.year, start.month, start.day, 0, 0, 0);
    to.value = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    await fetchRecords();
  }

  Future<void> setEmployee(String? employeeId) async {
    if (!isBillingActive) return;
    selectedEmployeeId.value = employeeId; // null = todos
    await fetchRecords();
  }

  Future<void> _loadEmployees() async {
    final companyId = brain.company.value?.id;
    if (companyId == null) return;

   final Result<List<EmployeeModel>> res = await getEmployeesByCompanyIdUseCase.call(
      companyId: companyId,
      includeDeleted: true
    );

    if (!res.success) {
      errorText.value = 'Error al cargar empleados: ${res.errorCode}';
      return;
    } else {
      employees.addAll(res.data);
      employees.sort((a, b) => a.accountStatus!.index.compareTo(b.accountStatus!.index));
    }


    if (!isBillingActive && employees.isNotEmpty) {
      selectedEmployeeId.value = employees.first.uid;
    }
  }

  Future<void> fetchRecords() async {
    isLoading.value = true;
    errorText.value = null;
    rows.clear();

    try {
      final companyId = brain.company.value?.id;
      if (companyId == null) {
        isLoading.value = false;
        return;
      }

      // decidir employeeId a filtrar (según facturación)
      String? employeeIdFilter;
      if (!isBillingActive) {
        employeeIdFilter = selectedEmployeeId.value ??
            (employees.isNotEmpty ? employees.first.uid : null);
      } else {
        employeeIdFilter = selectedEmployeeId.value;
      }

      final records = await getCompanyClockRecordsUseCase(
        companyId: companyId,
        from: from.value,
        to: to.value,
        employeeId: employeeIdFilter,
      );

      final dateFmt = DateFormat.Hm();
      final nameCache = <String, String>{
        for (var e in employees) e.uid: e.name
      };
      final now = DateTime.now();

      for (final item in records) {
        final inDt = item.clockIn;
        final outDt = item.clockOut ?? now;

        final worked =
            outDt.difference(inDt).inMinutes.clamp(0, 24 * 60);

        final employeeName =
            nameCache[item.employeeId] ?? item.employeeId;

        final rangeText =
            "${dateFmt.format(inDt)}–${item.clockOut == null ? '…' : dateFmt.format(outDt)}";

        rows.add(
          ClockRowView(
            day: DateTime(inDt.year, inDt.month, inDt.day),
            employeeName: employeeName,
            rangeText: rangeText,
            workedMinutes: worked,
            expectedMinutes: expectedDailyMinutes,
          ),
        );
      }
    } catch (e) {
      print(e);
      errorText.value = 'Error al cargar fichajes: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> openDayDetails(BuildContext context, ClockRowView row) async {
    final companyId = brain.company.value?.id;
    if (companyId == null) return;

    String? employeeId = selectedEmployeeId.value;

    if (employeeId == null) {
      try {
        final match = employees.firstWhere(
          (e) => e.name == row.employeeName,
        );
        employeeId = match.uid;
      } catch (_) {
        return;
      }
    }

    final records = await getEmployeeDayClockRecordsUseCase(
      companyId: companyId,
      employeeId: employeeId,
      day: row.day,
    );

    if (records.isEmpty) return;

    await showClockingsDayModal(
      context: context,
      employeeName: row.employeeName,
      employeeEmail: null,
      day: row.day,
      records: records,
    );
  }

  void redirectToReportsPage() {
    Get.toNamed(Routes.companyClockReports);
  }
}