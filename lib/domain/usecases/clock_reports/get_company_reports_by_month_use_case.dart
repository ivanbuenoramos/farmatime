import 'package:farmatime/data/models/clock_report.dart';
import 'package:farmatime/domain/repositories/clock_report_repository.dart';

class GetCompanyReportsByMonthUseCase {
  final ClockReportRepository repository;

  GetCompanyReportsByMonthUseCase(this.repository);

  Future<List<ClockReport>> call({
    required String companyId,
    required int year,
    required int month,
  }) {
    return repository.getCompanyReportsByMonth(
      companyId: companyId,
      year: year,
      month: month,
    );
  }
}