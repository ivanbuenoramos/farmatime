// lib/presentation/pages/leave/request/request_leave_controller.dart
import 'package:get/get.dart';
import 'package:flutter/material.dart';

enum LeaveType { vacaciones, personales }
enum LeaveSelectionMode { range, multiple } // rango o días sueltos

class RequestLeaveController extends GetxController {
  // Tipo de permiso
  final Rx<LeaveType?> leaveType = Rx<LeaveType?>(LeaveType.vacaciones);

  // Modo de selección
  final Rx<LeaveSelectionMode> selectionMode = LeaveSelectionMode.range.obs;

  // Estado para rango
  final Rx<DateTime?> startDate = Rx<DateTime?>(null);
  final Rx<DateTime?> endDate   = Rx<DateTime?>(null);

  // Estado para días sueltos
  final RxList<DateTime> selectedDays = <DateTime>[].obs;

  // Nota
  final TextEditingController noteCtrl = TextEditingController();

  final RxBool submitting = false.obs;

  // Helpers fecha
  DateTime _strip(DateTime d) => DateTime(d.year, d.month, d.day);

  void setLeaveType(LeaveType t) => leaveType.value = t;

  void setSelectionMode(LeaveSelectionMode m) {
    selectionMode.value = m;
    // Opcional: limpiar el otro modo
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
    endDate.value   = b.isAfter(a)  ? b : a;
  }

  Future<void> pickRange(BuildContext context) async {
    final now = DateTime.now();
    final initialStart = startDate.value ?? DateTime(now.year, now.month, now.day);
    final initialEnd   = endDate.value   ?? initialStart;

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      firstDate: DateTime(now.year - 1, 1, 1),
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
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: 'Selecciona un día',
      locale: const Locale('es', 'ES'),
    );
    if (picked != null) addDay(picked);
  }

  void addDay(DateTime d) {
    final day = _strip(d);
    // evitar duplicados
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

  bool get isValid {
    if (leaveType.value == null) return false;
    if (selectionMode.value == LeaveSelectionMode.range) {
      return startDate.value != null && endDate.value != null && totalDays > 0;
    } else {
      return selectedDays.isNotEmpty;
    }
  }

  // Solo UI
  Future<void> submit() async {
    if (!isValid || submitting.value) return;
    submitting.value = true;
    await Future.delayed(const Duration(milliseconds: 400));

    final typeText = leaveType.value == LeaveType.vacaciones ? 'Vacaciones' : 'Asuntos propios';
    Get.snackbar(
      'Solicitud creada',
      'Tipo: $typeText · $totalDays día(s)',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 2),
    );
    submitting.value = false;
  }

  @override
  void onClose() {
    noteCtrl.dispose();
    super.onClose();
  }
}