// lib/presentation/pages/company/entries/company_entries_controller.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/clock_in_out_model.dart';
import 'package:farmatime/presentation/widgets/modals/day_clockings_modal.dart';

import 'package:farmatime/domain/usecases/clock/get_employee_day_clock_records_usecase.dart';
import 'package:farmatime/domain/usecases/employee/get_employees_by_company_id_usecase.dart';
import 'package:farmatime/domain/usecases/clock/stream_company_clock_records_usecase.dart';

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
  CompanyEntriesController({
    required this.streamCompanyClockRecordsUseCase,
    required this.getEmployeeDayClockRecordsUseCase,
    required this.getEmployeesByCompanyIdUseCase,
  });

  final Brain brain = Get.find<Brain>();

  // Usecases
  final StreamCompanyClockRecordsUseCase streamCompanyClockRecordsUseCase;
  final GetEmployeeDayClockRecordsUseCase getEmployeeDayClockRecordsUseCase;
  final GetEmployeesByCompanyIdUseCase getEmployeesByCompanyIdUseCase;

  // Filtros
  final Rx<DateTime> from = Rx<DateTime>(_todayStart());
  final Rx<DateTime> to = Rx<DateTime>(_todayEnd());
  final RxnString selectedEmployeeId = RxnString(null); // null = "Todos"

  // Datos soporte
  final RxList<EmployeeModel> employees = <EmployeeModel>[].obs;

  // Tabla
  final RxList<ClockRowView> rows = <ClockRowView>[].obs;
  final RxBool isLoading = false.obs;
  final RxnString errorText = RxnString();

  // Config
  final int expectedDailyMinutes = 480; // 8h

  // Stream + cache + tick
  StreamSubscription<List<ClockInOutModel>>? _recordsSub;
  List<ClockInOutModel> _lastRecords = const [];
  Timer? _tickTimer;

  bool get isBillingActive =>
      (brain.company.value?.billingStatus ?? 'active') == 'active';

  String? get _companyId => brain.company.value?.id;

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
    _loadEmployees().then((_) {
      _bindRecordsStream();
      _startTicking();
    });
  }

  @override
  void onClose() {
    _recordsSub?.cancel();
    _tickTimer?.cancel();
    super.onClose();
  }

  Future<void> setRange(DateTime start, DateTime end) async {
    if (end.difference(start).inDays > 31) {
      errorText.value = 'El rango máximo es de 1 mes.';
      return;
    }

    from.value = DateTime(start.year, start.month, start.day, 0, 0, 0);
    to.value = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);

    _bindRecordsStream();
  }

  Future<void> setEmployee(String? employeeId) async {
    if (!isBillingActive) return; // tu regla
    selectedEmployeeId.value = employeeId; // null = todos
    _bindRecordsStream();
  }

  Future<void> _loadEmployees() async {
    final companyId = _companyId;
    if (companyId == null || companyId.isEmpty) return;

    final Result<List<EmployeeModel>> res =
        await getEmployeesByCompanyIdUseCase.call(
      companyId: companyId,
      includeDeleted: true,
    );

    if (!res.success) {
      errorText.value = 'Error al cargar empleados: ${res.errorCode}';
      return;
    }

    employees
      ..clear()
      ..addAll(res.data);

    employees.sort((a, b) =>
        (a.accountStatus?.index ?? 0).compareTo(b.accountStatus?.index ?? 0));

    // Si billing NO activo: solo deja ver el primero (según tu lógica previa)
    if (!isBillingActive && employees.isNotEmpty) {
      selectedEmployeeId.value = employees.first.uid;
    }
  }

  void _bindRecordsStream() {
    final companyId = _companyId;
    if (companyId == null || companyId.isEmpty) {
      errorText.value = 'Falta el ID de empresa.';
      return;
    }

    // decidir employeeId a filtrar (según facturación)
    String? employeeIdFilter;
    if (!isBillingActive) {
      employeeIdFilter =
          selectedEmployeeId.value ?? (employees.isNotEmpty ? employees.first.uid : null);
    } else {
      employeeIdFilter = selectedEmployeeId.value; // null = todos
    }

    isLoading.value = true;
    errorText.value = null;

    _recordsSub?.cancel();
    _recordsSub = streamCompanyClockRecordsUseCase(
      companyId: companyId,
      from: from.value,
      to: to.value,
      employeeId: employeeIdFilter,
    ).listen(
      (records) {
        _lastRecords = records;
        _buildRowsFromRecords(records);
        isLoading.value = false;
      },
      onError: (e) {
        print(to);
        isLoading.value = false;
        errorText.value = 'Error al cargar fichajes: $e';
      },
    );
  }

  void _buildRowsFromRecords(List<ClockInOutModel> records) {
    final dateFmt = DateFormat.Hm();

    // cache de nombres
    final nameCache = <String, String>{
      for (final e in employees) e.uid: e.name,
    };

    final now = DateTime.now();
    final newRows = <ClockRowView>[];

    for (final item in records) {
      final inDt = item.clockIn;
      final outDt = item.clockOut ?? now;

      final worked = outDt.difference(inDt).inMinutes.clamp(0, 24 * 60);

      final employeeName = nameCache[item.employeeId] ?? item.employeeId;

      final rangeText =
          "${dateFmt.format(inDt)}–${item.clockOut == null ? '…' : dateFmt.format(outDt)}";

      newRows.add(
        ClockRowView(
          day: DateTime(inDt.year, inDt.month, inDt.day),
          employeeName: employeeName,
          rangeText: rangeText,
          workedMinutes: worked,
          expectedMinutes: expectedDailyMinutes,
        ),
      );
    }

    rows.value = newRows;
  }

  void _startTicking() {
    _tickTimer?.cancel();

    // Para que los fichajes "abiertos" (clockOut null) vayan actualizando minutos
    _tickTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_lastRecords.isEmpty) return;
      // reconstruye con "now" actualizado
      _buildRowsFromRecords(_lastRecords);
    });
  }

  Future<void> openDayDetails(BuildContext context, ClockRowView row) async {
    final companyId = _companyId;
    if (companyId == null || companyId.isEmpty) return;

    String? employeeId = selectedEmployeeId.value;

    // Si estás en "Todos", intentas resolver por nombre (tu lógica)
    if (employeeId == null) {
      try {
        final match = employees.firstWhere((e) => e.name == row.employeeName);
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