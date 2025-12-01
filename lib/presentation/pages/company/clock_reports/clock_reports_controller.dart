import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/clock_report.dart';
import 'package:farmatime/domain/usecases/clock_reports/generate_current_month_to_date_reports_use_case.dart';
import 'package:farmatime/domain/usecases/clock_reports/get_company_reports_by_month_use_case.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class ClockReportsController extends GetxController {
  final GetCompanyReportsByMonthUseCase getCompanyReportsByMonthUseCase;
  final GenerateCurrentMonthToDateReportsUseCase generateCurrentMonthToDateReportsUseCase;


  ClockReportsController({
    required this.getCompanyReportsByMonthUseCase,
    required this.generateCurrentMonthToDateReportsUseCase,
  });

  final brain = Get.find<Brain>();

  final RxInt selectedYear = DateTime.now().year.obs;
  final RxInt selectedMonth = DateTime.now().month.obs;

  final reports = <ClockReport>[].obs;

  final isLoading = false.obs;
  final isGenerating = false.obs;
  final errorMessage = RxString('');

  List<int> get availableYears {
    final now = DateTime.now();
    // Por ejemplo últimos 3 años: ajusta a lo que quieras
    return [now.year - 2, now.year - 1, now.year];
  }

  String monthName(int m) {
    final date = DateTime(2000, m, 1);
    return DateFormat.MMMM('es_ES').format(date); // "enero", "febrero", etc
  }

  @override
  void onInit() {
    super.onInit();
    loadReportsForSelectedMonth();
  }

  Future<void> loadReportsForSelectedMonth() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final list = await getCompanyReportsByMonthUseCase.call(
        companyId: brain.company.value!.id,
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

  Future<void> generateCurrentMonthToDate() async {
    isGenerating.value = true;
    errorMessage.value = '';
    try {
      await generateCurrentMonthToDateReportsUseCase.call(
        companyId: brain.company.value!.id,
      );
      // Después de generar, recargamos el mes actual
      await loadReportsForSelectedMonth();
    } catch (e) {
      errorMessage.value = 'Error generando reportes: $e';
    } finally {
      isGenerating.value = false;
    }
  }
}