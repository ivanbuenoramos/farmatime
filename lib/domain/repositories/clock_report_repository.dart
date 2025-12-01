import 'package:farmatime/data/models/clock_report.dart';


abstract class ClockReportRepository {
  /// Lista de reportes de una farmacia para un mes concreto.
  Future<List<ClockReport>> getCompanyReportsByMonth({
    required String companyId,
    required int year,
    required int month,
  });

  /// Genera reportes desde el día 1 del mes actual hasta hoy
  /// llamando a la Cloud Function (reportsGenerateRange).
  Future<void> generateCurrentMonthToDateReports({
    required String companyId,
  });

  /// Obtiene los reportes de un empleado paginados de 10 en 10.
  /// startAfterPeriodStart = cursor (último periodStart recibido anteriormente).
  Future<ClockReportPage> getEmployeeReportsPaginated({
    required String companyId,
    required String employeeId,
    DateTime? startAfterPeriodStart,
    int pageSize,
  });
}