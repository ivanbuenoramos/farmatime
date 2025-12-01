import 'package:farmatime/domain/repositories/clock_report_repository.dart';

class GenerateCurrentMonthToDateReportsUseCase {
  final ClockReportRepository repository;

  GenerateCurrentMonthToDateReportsUseCase(this.repository);

  Future<void> call({required String companyId}) {
    return repository.generateCurrentMonthToDateReports(
      companyId: companyId,
    );
  }
}