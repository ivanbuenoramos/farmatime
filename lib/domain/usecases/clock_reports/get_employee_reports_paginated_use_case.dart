import 'package:farmatime/data/models/clock_report.dart';
import 'package:farmatime/domain/repositories/clock_report_repository.dart';

class GetEmployeeReportsPaginatedUseCase {
  final ClockReportRepository repository;

  GetEmployeeReportsPaginatedUseCase(this.repository);

  Future<ClockReportPage> call({
    required String companyId,
    required String employeeId,
    DateTime? startAfterPeriodStart,
    int pageSize = 10,
  }) {
    return repository.getEmployeeReportsPaginated(
      companyId: companyId,
      employeeId: employeeId,
      startAfterPeriodStart: startAfterPeriodStart,
      pageSize: pageSize,
    );
  }
}