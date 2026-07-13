// lib/presentation/pages/employee/request_leave/request_leave_controller.dart
import 'dart:async';

import 'package:get/get.dart';
import 'package:flutter/material.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/services/toast_service.dart';
import 'package:farmatime/core/utils/leave_dates_utils.dart';
import 'package:farmatime/core/utils/leave_simple_utils.dart';
import 'package:farmatime/data/models/schedule/time_off_model.dart';
import 'package:farmatime/domain/usecases/time_off/create_time_off_usecase.dart';
import 'package:farmatime/domain/usecases/time_off/decide_time_off_usecase.dart';
import 'package:farmatime/domain/usecases/time_off/stream_time_off_by_employee_usecase.dart';

enum LeaveType { vacaciones, personales }
enum LeaveSelectionMode { range, multiple } // rango o días sueltos

class RequestLeaveController extends GetxController {
  RequestLeaveController({
    required this.createTimeOffUseCase,
    required this.streamByEmployeeUseCase,
    required this.decideTimeOffUseCase,
  });

  final CreateTimeOffUseCase createTimeOffUseCase;
  final StreamTimeOffByEmployeeUseCase streamByEmployeeUseCase;
  final DecideTimeOffUseCase decideTimeOffUseCase;

  final Brain brain = Get.find<Brain>();
  final ToastService toast = ToastService();

  // Tipo de permiso
  final Rx<LeaveType?> leaveType = Rx<LeaveType?>(LeaveType.vacaciones);

  // Modo de selección
  final Rx<LeaveSelectionMode> selectionMode = LeaveSelectionMode.range.obs;

  // Estado para rango
  final Rx<DateTime?> startDate = Rx<DateTime?>(null);
  final Rx<DateTime?> endDate = Rx<DateTime?>(null);

  // Estado para días sueltos
  final RxList<DateTime> selectedDays = <DateTime>[].obs;

  // Nota
  final TextEditingController noteCtrl = TextEditingController();

  final RxBool submitting = false.obs;

  // Mis solicitudes (real-time)
  final RxList<TimeOffModel> myRequests = <TimeOffModel>[].obs;
  final RxBool loadingRequests = true.obs;
  StreamSubscription<List<TimeOffModel>>? _requestsSub;
  final RxnString decidingId = RxnString(); // id en proceso de aceptar/rechazar

  String get _companyId => brain.employee.value?.companyId ?? '';
  String get _employeeId => brain.employee.value?.uid ?? '';

  // ─────────────────────────────────────────────
  // Saldos de vacaciones y asuntos propios
  // ─────────────────────────────────────────────

  /// Saldos calculados a partir del devengo del empleado y los días aprobados
  /// presentes en [myRequests]. Reactivo: se recalcula al cambiar las
  /// solicitudes. Devuelve null si aún no hay empleado.
  SimpleLeaveBalances? get balances {
    final emp = brain.employee.value;
    if (emp == null) return null;
    return computeBalancesWithRequests(
      employee: emp,
      requests: myRequests,
      hireDateOverride: emp.createdAt,
    );
  }

  /// Cuenta los días aprobados de un tipo, separando si su fecha ya pasó
  /// (gastados) o todavía no ha llegado (asignados a futuro). El día de hoy
  /// cuenta como gastado.
  ({int upcoming, int spent}) _approvedSplit(TimeOffType type) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    var upcoming = 0;
    var spent = 0;

    for (final r in myRequests) {
      if (r.status != TimeOffStatus.approved) continue;
      if (r.type != type) continue;
      for (final ymd in r.effectiveDates) {
        final d = DateTime.tryParse(ymd);
        if (d == null) continue;
        final dayOnly = DateTime(d.year, d.month, d.day);
        if (dayOnly.isAfter(todayOnly)) {
          upcoming++;
        } else {
          spent++;
        }
      }
    }
    return (upcoming: upcoming, spent: spent);
  }

  /// Días aprobados con fecha futura (otorgados pero aún no disfrutados).
  int get vacationUpcoming => _approvedSplit(TimeOffType.vacation).upcoming;
  int get personalUpcoming => _approvedSplit(TimeOffType.personal).upcoming;

  /// Días aprobados con fecha ya pasada (realmente disfrutados).
  int get vacationSpent => _approvedSplit(TimeOffType.vacation).spent;
  int get personalSpent => _approvedSplit(TimeOffType.personal).spent;

  /// Texto de cadencia: cada cuántos días naturales se gana un día de
  /// vacaciones. Deriva de [vacationDaysPer30] (días por cada 30).
  String get vacationCadenceLabel {
    final perDay = brain.employee.value?.vacationDaysPer30 ?? 0;
    if (perDay <= 0) return 'Sin devengo configurado';
    final daysPerEarned = 30.0 / perDay;
    return 'Ganas 1 día cada ${_fmtCadence(daysPerEarned)}.';
  }

  /// Texto de cadencia para asuntos propios. Deriva de [personalDaysPerYear].
  String get personalCadenceLabel {
    final perYear = brain.employee.value?.personalDaysPerYear ?? 0;
    if (perYear <= 0) return 'Sin devengo configurado';
    final daysPerEarned = 365.0 / perYear;
    return 'Ganas 1 día cada ${_fmtCadence(daysPerEarned)}.';
  }

  /// Formatea una cadencia en días a un texto legible (días/semanas/meses).
  String _fmtCadence(double days) {
    if (days < 1) {
      final perDay = (1 / days);
      final n = perDay.round();
      return n <= 1 ? 'día' : '${_fmtNum(perDay)} al día';
    }
    if (days < 14) {
      return '${_fmtNum(days)} día${days == 1 ? '' : 's'}';
    }
    if (days < 60) {
      final weeks = days / 7.0;
      return '${_fmtNum(weeks)} semana${weeks == 1 ? '' : 's'}';
    }
    final months = days / 30.0;
    return '${_fmtNum(months)} mes${months == 1 ? '' : 'es'}';
  }

  String _fmtNum(double v) {
    final r = _round1(v);
    if (r == r.roundToDouble()) return r.toInt().toString();
    return r.toStringAsFixed(1).replaceAll('.', ',');
  }

  double _round1(double v) => double.parse(v.toStringAsFixed(1));

  @override
  void onInit() {
    super.onInit();
    _bindMyRequests();
  }

  void _bindMyRequests() {
    if (_companyId.isEmpty || _employeeId.isEmpty) {
      loadingRequests.value = false;
      return;
    }
    _requestsSub?.cancel();
    _requestsSub = streamByEmployeeUseCase
        .call(companyId: _companyId, employeeId: _employeeId)
        .listen((list) {
      myRequests.assignAll(list);
      loadingRequests.value = false;
    }, onError: (_) {
      loadingRequests.value = false;
    });
  }

  // Helpers fecha
  DateTime _strip(DateTime d) => DateTime(d.year, d.month, d.day);

  void setLeaveType(LeaveType t) => leaveType.value = t;

  void setSelectionMode(LeaveSelectionMode m) {
    selectionMode.value = m;
    if (m == LeaveSelectionMode.range) {
      selectedDays.clear();
    } else {
      startDate.value = null;
      endDate.value = null;
    }
  }

  // ---- Rango ----
  void setRange(DateTime s, DateTime e) {
    final a = _strip(s);
    final b = _strip(e);
    startDate.value = a.isBefore(b) ? a : b;
    endDate.value = b.isAfter(a) ? b : a;
  }

  Future<void> pickRange(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initialStart = startDate.value ?? today;
    final initialEnd = endDate.value ?? initialStart;

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      // No se pueden solicitar ausencias en el pasado.
      firstDate: today,
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: 'Selecciona el rango',
      saveText: 'Aceptar',
      locale: const Locale('es', 'ES'),
    );

    if (picked != null) {
      setRange(picked.start, picked.end);
    }
  }

  // ---- Días sueltos ----
  Future<void> pickSingleDay(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      // No se pueden solicitar ausencias en el pasado.
      firstDate: today,
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: 'Selecciona un día',
      locale: const Locale('es', 'ES'),
    );
    if (picked != null) addDay(picked);
  }

  void addDay(DateTime d) {
    final day = _strip(d);
    if (!selectedDays.any((x) => x.year == day.year && x.month == day.month && x.day == day.day)) {
      selectedDays.add(day);
      selectedDays.sort((a, b) => a.compareTo(b));
    }
  }

  void removeDay(DateTime d) {
    selectedDays.removeWhere((x) => x.year == d.year && x.month == d.month && x.day == d.day);
  }

  // ---- Validación y totales ----
  int get totalDays {
    if (selectionMode.value == LeaveSelectionMode.range) {
      final s = startDate.value;
      final e = endDate.value;
      if (s == null || e == null) return 0;
      return e.difference(s).inDays + 1; // inclusivo
    } else {
      return selectedDays.length;
    }
  }

  /// Días disponibles del tipo seleccionado (ya descuenta lo aprobado).
  double get availableForSelectedType {
    final b = balances;
    if (b == null) return 0;
    return leaveType.value == LeaveType.vacaciones
        ? b.vacationAvailable
        : b.personalAvailable;
  }

  /// Los días solicitados superan el saldo disponible del tipo elegido.
  bool get exceedsBalance => totalDays > availableForSelectedType;

  bool get isValid {
    if (leaveType.value == null) return false;
    if (exceedsBalance) return false;
    if (selectionMode.value == LeaveSelectionMode.range) {
      return startDate.value != null && endDate.value != null && totalDays > 0;
    } else {
      return selectedDays.isNotEmpty;
    }
  }

  /// Construye la lista de fechas 'yyyy-MM-dd' según el modo de selección.
  List<String> _buildDates() {
    if (selectionMode.value == LeaveSelectionMode.range) {
      final s = startDate.value!;
      final e = endDate.value!;
      return expandRange(s, e);
    }
    return daysToYmd(selectedDays);
  }

  void _clearForm() {
    startDate.value = null;
    endDate.value = null;
    selectedDays.clear();
    noteCtrl.clear();
    selectionMode.value = LeaveSelectionMode.range;
    leaveType.value = LeaveType.vacaciones;
  }

  Future<void> submit() async {
    if (submitting.value) return;
    if (leaveType.value != null && totalDays > 0 && exceedsBalance) {
      final tipo = leaveType.value == LeaveType.vacaciones
          ? 'vacaciones'
          : 'asuntos propios';
      toast.show(
        title: 'Saldo insuficiente',
        message: 'Solicitas $totalDays día(s) de $tipo pero solo te quedan '
            '${availableForSelectedType.toStringAsFixed(1)}.',
        type: ToastType.warning,
      );
      return;
    }
    if (!isValid) return;
    if (_companyId.isEmpty || _employeeId.isEmpty) {
      toast.show(
        title: 'Sesión no válida',
        message: 'No se ha podido identificar tu cuenta. Vuelve a iniciar sesión.',
        type: ToastType.error,
      );
      return;
    }

    submitting.value = true;

    final note = noteCtrl.text.trim();
    final request = TimeOffModel(
      id: '',
      companyId: _companyId,
      employeeId: _employeeId,
      type: leaveType.value == LeaveType.vacaciones
          ? TimeOffType.vacation
          : TimeOffType.personal,
      status: TimeOffStatus.requested,
      dates: _buildDates(),
      note: note.isEmpty ? null : note,
    );

    final res = await createTimeOffUseCase.call(request);
    submitting.value = false;

    if (res.success) {
      _clearForm();
      toast.show(
        title: 'Solicitud enviada',
        message: 'Tu responsable la revisará en breve.',
        type: ToastType.success,
      );
    } else {
      toast.show(
        title: 'No se pudo enviar',
        message: 'Inténtalo de nuevo en unos instantes.',
        type: ToastType.error,
      );
    }
  }

  // ─────────────────────────────────────────────
  // Respuesta del empleado a una contrapropuesta
  // ─────────────────────────────────────────────
  Future<void> acceptProposal(TimeOffModel request) async {
    if (decidingId.value != null) return;
    decidingId.value = request.id;
    final res = await decideTimeOffUseCase.employeeAcceptProposal(
      request: request,
      decidedBy: _employeeId,
    );
    decidingId.value = null;
    if (res.success) {
      toast.show(
        title: 'Propuesta aceptada',
        message: 'Tus días quedan confirmados en el calendario.',
        type: ToastType.success,
      );
    }
  }

  Future<void> rejectProposal(TimeOffModel request) async {
    if (decidingId.value != null) return;
    decidingId.value = request.id;
    final res = await decideTimeOffUseCase.employeeRejectProposal(
      request: request,
      decidedBy: _employeeId,
    );
    decidingId.value = null;
    if (res.success) {
      toast.show(
        title: 'Propuesta rechazada',
        message: 'La solicitud se ha cerrado.',
        type: ToastType.info,
      );
    }
  }

  /// Cancela una solicitud propia que sigue pendiente. Pide confirmación.
  Future<void> cancelRequest(TimeOffModel request) async {
    if (decidingId.value != null) return;

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Cancelar solicitud'),
        content: const Text(
          '¿Seguro que quieres cancelar esta solicitud? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Cancelar solicitud'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    decidingId.value = request.id;
    final res = await decideTimeOffUseCase.employeeCancel(
      request: request,
      decidedBy: _employeeId,
    );
    decidingId.value = null;
    if (res.success) {
      toast.show(
        title: 'Solicitud cancelada',
        message: 'Tu solicitud ya no está pendiente.',
        type: ToastType.info,
      );
    }
  }

  @override
  void onClose() {
    _requestsSub?.cancel();
    noteCtrl.dispose();
    super.onClose();
  }
}
