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
import 'package:farmatime/domain/usecases/employee_schedule/get_expected_shift_usecase.dart';
import 'package:farmatime/data/models/employee_shift_model.dart';

class ClockRowView {
  final DateTime day;
  final String employeeId;
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
    required this.employeeId,
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
    required this.getExpectedShiftsForDayUseCase,
  });

  final Brain brain = Get.find<Brain>();

  // Usecases
  final StreamCompanyClockRecordsUseCase streamCompanyClockRecordsUseCase;
  final GetEmployeeDayClockRecordsUseCase getEmployeeDayClockRecordsUseCase;
  final GetEmployeesByCompanyIdUseCase getEmployeesByCompanyIdUseCase;
  final GetExpectedShiftsForDayUseCase getExpectedShiftsForDayUseCase;

  // Filtros
  final Rx<DateTime> from = Rx<DateTime>(_todayStart());
  final Rx<DateTime> to = Rx<DateTime>(_todayEnd());
  // Conjunto de empleados seleccionados. Vacío = "Todos".
  final RxSet<String> selectedEmployeeIds = <String>{}.obs;

  // Datos soporte
  final RxList<EmployeeModel> employees = <EmployeeModel>[].obs;

  // Tabla
  final RxList<ClockRowView> rows = <ClockRowView>[].obs;
  final RxBool isLoading = false.obs;
  final RxnString errorText = RxnString();

  // Minutos esperados por defecto cuando no hay turno asignado y no podemos
  // resolverlo (fallback de jornada completa: 8h).
  static const int _defaultFullDayMinutes = 480;

  // Cache de minutos esperados por día y empleado, resuelto desde el horario
  // real (override → regla recurrente). Clave día = 'yyyy-MM-dd'.
  // Se recalcula al cambiar de rango/records, NO en cada tick de 30s.
  final Map<String, Map<String, int>> _expectedByDay = {};

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

  /// Aplica una nueva selección de empleados. Conjunto vacío = "Todos".
  Future<void> setSelectedEmployees(Set<String> ids) async {
    if (!isBillingActive) return; // en plan gratuito la selección es fija
    selectedEmployeeIds
      ..clear()
      ..addAll(ids);
    // Filtrado en cliente: basta con reconstruir las filas.
    _buildRowsFromRecords(_lastRecords);
  }

  /// Alterna un empleado dentro de la selección.
  Future<void> toggleEmployee(String employeeId) async {
    if (!isBillingActive) return;
    if (selectedEmployeeIds.contains(employeeId)) {
      selectedEmployeeIds.remove(employeeId);
    } else {
      selectedEmployeeIds.add(employeeId);
    }
    _buildRowsFromRecords(_lastRecords);
  }

  /// IDs de empleados efectivamente visibles según el plan y la selección.
  /// Vacío = sin filtro (todos).
  Set<String> get _effectiveEmployeeIds {
    if (!isBillingActive) {
      return employees.isNotEmpty ? {employees.first.uid} : <String>{};
    }
    return selectedEmployeeIds.toSet();
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
  }

  void _bindRecordsStream() {
    final companyId = _companyId;
    if (companyId == null || companyId.isEmpty) {
      errorText.value = 'Falta el ID de empresa.';
      return;
    }

    // Traemos todos los registros del rango y filtramos por empleado en
    // cliente (permite multi-selección sin el límite de whereIn de Firestore).
    isLoading.value = true;
    errorText.value = null;

    _recordsSub?.cancel();
    _recordsSub = streamCompanyClockRecordsUseCase(
      companyId: companyId,
      from: from.value,
      to: to.value,
      employeeId: null,
    ).listen(
      (records) async {
        _lastRecords = records;
        await _resolveExpectedMinutes(records);
        _buildRowsFromRecords(records);
        isLoading.value = false;
      },
      onError: (e) {
        isLoading.value = false;
        errorText.value = 'Error al cargar fichajes: $e';
      },
    );
  }

  /// Resuelve, para cada día con fichajes, los minutos esperados de cada
  /// empleado a partir de su horario real (override → regla). Cachea el
  /// resultado para que el tick de 30s no relance consultas.
  Future<void> _resolveExpectedMinutes(List<ClockInOutModel> records) async {
    final companyId = _companyId;
    if (companyId == null || companyId.isEmpty) return;

    // Agrupa empleados por día presentes en los fichajes.
    final byDay = <String, Set<String>>{};
    for (final r in records) {
      final inDt = r.clockIn;
      final key = DateFormat('yyyy-MM-dd')
          .format(DateTime(inDt.year, inDt.month, inDt.day));
      byDay.putIfAbsent(key, () => <String>{}).add(r.employeeId);
    }

    _expectedByDay.clear();
    for (final entry in byDay.entries) {
      final dayKey = entry.key;
      final dayDate = DateTime.parse(dayKey);
      final res = await getExpectedShiftsForDayUseCase.call(
        companyId: companyId,
        employeeIds: entry.value.toList(),
        dayDate: dayDate,
        dayKey: dayKey,
      );
      if (!res.success) continue;

      final perEmp = <String, int>{};
      res.data.forEach((empId, ExpectedShiftModel? shift) {
        // Día libre (sin turno) → 0 minutos esperados (no penaliza al empleado).
        perEmp[empId] = shift == null
            ? 0
            : shift.end.difference(shift.start).inMinutes.clamp(0, 24 * 60);
      });
      _expectedByDay[dayKey] = perEmp;
    }
  }

  int _expectedMinutesFor(String employeeId, DateTime day) {
    final key = DateFormat('yyyy-MM-dd').format(day);
    final perEmp = _expectedByDay[key];
    if (perEmp == null || !perEmp.containsKey(employeeId)) {
      // Sin dato de horario resuelto: usamos jornada completa como fallback.
      return _defaultFullDayMinutes;
    }
    return perEmp[employeeId]!;
  }

  void _buildRowsFromRecords(List<ClockInOutModel> records) {
    final dateFmt = DateFormat.Hm();

    // cache de nombres
    final nameCache = <String, String>{
      for (final e in employees) e.uid: e.name,
    };

    final now = DateTime.now();
    final newRows = <ClockRowView>[];

    // Filtro en cliente: si hay IDs efectivos, solo esos; vacío = todos.
    final allowedIds = _effectiveEmployeeIds;

    for (final item in records) {
      if (allowedIds.isNotEmpty && !allowedIds.contains(item.employeeId)) {
        continue;
      }

      final inDt = item.clockIn;
      final outDt = item.clockOut ?? now;

      final worked = outDt.difference(inDt).inMinutes.clamp(0, 24 * 60);

      final employeeName = nameCache[item.employeeId] ?? item.employeeId;

      final rangeText =
          "${dateFmt.format(inDt)}–${item.clockOut == null ? '…' : dateFmt.format(outDt)}";

      final day = DateTime(inDt.year, inDt.month, inDt.day);
      newRows.add(
        ClockRowView(
          day: day,
          employeeId: item.employeeId,
          employeeName: employeeName,
          rangeText: rangeText,
          workedMinutes: worked,
          expectedMinutes: _expectedMinutesFor(item.employeeId, day),
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

    if (row.employeeId.isEmpty) return;

    final records = await getEmployeeDayClockRecordsUseCase(
      companyId: companyId,
      employeeId: row.employeeId,
      day: row.day,
    );

    if (records.isEmpty) return;

    await showClockingsDayModal(
      context: context,
      employeeName: row.employeeName,
      employeeEmail: null,
      employeeUid: row.employeeId,
      day: row.day,
      records: records,
    );
  }

  void redirectToReportsPage() {
    Get.toNamed(Routes.companyClockReports);
  }
}