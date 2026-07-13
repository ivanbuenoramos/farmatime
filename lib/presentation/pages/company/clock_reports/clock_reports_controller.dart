import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/clock_report.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/domain/usecases/clock_reports/get_company_reports_by_month_use_case.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Fila combinada empleado + (opcional) reporte del mes seleccionado.
class EmployeeMonthReportRow {
  final EmployeeModel employee;
  final ClockReport? report;

  EmployeeMonthReportRow({required this.employee, required this.report});

  bool get hasReport => report != null;
  bool get hasActivity => (report?.recordsCount ?? 0) > 0;
}

class ClockReportsController extends GetxController {
  final GetCompanyReportsByMonthUseCase getCompanyReportsByMonthUseCase;

  ClockReportsController({required this.getCompanyReportsByMonthUseCase});

  final brain = Get.find<Brain>();

  /// Mes/año seleccionado. Por defecto, el mes anterior (para el que ya hay PDF).
  late final RxInt selectedYear;
  late final RxInt selectedMonth;

  final reports = <ClockReport>[].obs;
  final isLoading = false.obs;
  final errorMessage = RxString('');

  @override
  void onInit() {
    super.onInit();
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    selectedYear = lastMonth.year.obs;
    selectedMonth = lastMonth.month.obs;
    loadReportsForSelectedMonth();
  }

  // ---- Helpers de presentación ----

  String monthName(int m) {
    final date = DateTime(2000, m, 1);
    return DateFormat.MMMM('es_ES').format(date);
  }

  String monthLongLabel(int year, int month) {
    final date = DateTime(year, month, 1);
    final raw = DateFormat("MMMM 'de' y", 'es_ES').format(date);
    return raw[0].toUpperCase() + raw.substring(1);
  }

  bool get isCurrentMonth {
    final now = DateTime.now();
    return selectedYear.value == now.year && selectedMonth.value == now.month;
  }

  bool get isFutureMonth {
    final now = DateTime.now();
    final sel = DateTime(selectedYear.value, selectedMonth.value, 1);
    final cur = DateTime(now.year, now.month, 1);
    return sel.isAfter(cur);
  }

  /// Últimos 12 meses (incluido el actual), en orden cronológico ascendente.
  List<DateTime> get availableMonths {
    final now = DateTime.now();
    return List.generate(12, (i) {
      return DateTime(now.year, now.month - 11 + i, 1);
    });
  }

  void selectMonth(DateTime month) {
    selectedYear.value = month.year;
    selectedMonth.value = month.month;
    loadReportsForSelectedMonth();
  }

  // ---- Carga ----

  Future<void> loadReportsForSelectedMonth() async {
    final companyId = brain.company.value?.id;
    if (companyId == null) return;

    isLoading.value = true;
    errorMessage.value = '';
    try {
      final list = await getCompanyReportsByMonthUseCase.call(
        companyId: companyId,
        year: selectedYear.value,
        month: selectedMonth.value,
      );
      reports.assignAll(list);
    } catch (e) {
      errorMessage.value = 'Error cargando reportes: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// Une la lista de empleados con sus reportes del mes (left join).
  /// Excluye empleados borrados.
  List<EmployeeMonthReportRow> get rows {
    final byEmployee = <String, ClockReport>{
      for (final r in reports) r.employeeId: r,
    };

    final employees = brain.companyEmployees
        .where((e) => e.accountStatus != EmployeeAccountStatus.deleted)
        .toList()
      ..sort((a, b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return employees
        .map((e) =>
            EmployeeMonthReportRow(employee: e, report: byEmployee[e.uid]))
        .toList();
  }

  // ---- Métricas resumen del mes ----
  int get totalReports => reports.length;

  double get totalHoursMonth =>
      reports.fold(0.0, (acc, r) => acc + r.totalHours);

  int get totalEmployeesWithActivity =>
      reports.where((r) => r.recordsCount > 0).length;
}
