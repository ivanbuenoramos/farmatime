import 'package:farmatime/core/app/brain.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:farmatime/data/models/clock_in_out_model.dart';

class EmployeeOption {
  final String id;
  final String name;

  EmployeeOption({required this.id, required this.name});
}

class ClockRowView {
  final DateTime day;
  final String employeeName;
  final String rangeText;        // "08:00–16:12" (o "08:00–…" si clockOut null)
  final int workedMinutes;       // minutos efectivos (hasta ahora si no hay salida)
  final int expectedMinutes;     // meta diaria en min (por defecto 480)
  int get diffMinutes => workedMinutes - expectedMinutes;
  String get workedHhMm =>
      "${(workedMinutes ~/ 60)}:${(workedMinutes % 60).toString().padLeft(2, '0')}";
  String get expectedHhMm =>
      "${(expectedMinutes ~/ 60)}h${expectedMinutes % 60 == 0 ? '' : ' ${(expectedMinutes % 60)} min'}";
  String get diffSigned =>
      "${diffMinutes >= 0 ? '+' : '-'}${diffMinutes.abs() ~/ 60 > 0 ? '${diffMinutes.abs() ~/ 60}h ' : ''}${(diffMinutes.abs() % 60)}m";

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
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Filtros
  final Rx<DateTime> from = Rx<DateTime>(_todayStart());
  final Rx<DateTime> to = Rx<DateTime>(_todayEnd());
  final RxnString selectedEmployeeId = RxnString(null); // null = "Todos"

  // Datos soporte
  final employees = <EmployeeOption>[].obs;

  // Tabla
  final rows = <ClockRowView>[].obs;
  final isLoading = false.obs;
  final errorText = RxnString();

  // Config
  final int expectedDailyMinutes = 480; // 8h por defecto

  // 👉 Estado de facturación
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
    // Limitar a 31 días
    if (end.difference(start).inDays > 31) {
      errorText.value = 'El rango máximo es de 1 mes.';
      return;
    }
    from.value = DateTime(start.year, start.month, start.day, 0, 0, 0);
    to.value = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    await fetchRecords();
  }

  Future<void> setEmployee(String? employeeId) async {
    // 👉 En plan no activo, no dejamos cambiar de empleado
    if (!isBillingActive) {
      return;
    }
    selectedEmployeeId.value = employeeId; // null = todos
    await fetchRecords();
  }

  Future<void> _loadEmployees() async {
    final companyId = brain.company.value?.id;
    if (companyId == null) return;

    final snap = await _db
        .collection('employees')
        .where('companyId', isEqualTo: companyId)
        .where('accountStatus', isEqualTo: 'active')
        .orderBy('name')
        .get();

    employees.assignAll(
      snap.docs.map((d) {
        final data = d.data();
        return EmployeeOption(
          id: data['id'] ?? d.id,
          name: data['name'] ?? 'Sin nombre',
        );
      }).toList(),
    );

    // 👉 Si la facturación NO está activa y hay empleados activos,
    // forzamos el primero para filtros
    if (!isBillingActive && employees.isNotEmpty) {
      selectedEmployeeId.value = employees.first.id;
    }
  }

  Future<void> fetchRecords() async {
    isLoading.value = true;
    errorText.value = null;
    rows.clear();

    try {
      Query col = _db
          .collection('clockRecords')
          .where('companyId', isEqualTo: brain.company.value?.id)
          .where('clockIn',
              isGreaterThanOrEqualTo: from.value.toIso8601String())
          .where('clockIn', isLessThanOrEqualTo: to.value.toIso8601String());

      // 🔒 Restricción por facturación
      if (!isBillingActive) {
        // Forzar siempre al primer empleado creado
        final forcedId =
            selectedEmployeeId.value ?? (employees.isNotEmpty ? employees.first.id : null);
        if (forcedId != null) {
          col = col.where('employeeId', isEqualTo: forcedId);
        }
      } else {
        // Flujo normal: filtros
        if (selectedEmployeeId.value != null) {
          col = col.where('employeeId', isEqualTo: selectedEmployeeId.value);
        }
      }

      // Orden descendente por clockIn
      final snap = await col.orderBy('clockIn', descending: true).get();

      final dateFmt = DateFormat.Hm();
      final nameCache = <String, String>{
        for (var e in employees) e.id: e.name
      };

      final now = DateTime.now();

      for (final doc in snap.docs) {
        final data = doc.data();
        final item = ClockInOutModel.fromJson(data as Map<String, dynamic>);

        final inDt = item.clockIn;
        final outDt = item.clockOut ?? now;

        final worked =
            outDt.difference(inDt).inMinutes.clamp(0, 24 * 60);

        final employeeName = nameCache[item.employeeId] ?? item.employeeId;

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
}