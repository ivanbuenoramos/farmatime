import 'package:farmatime/domain/repositories/clock_repository.dart';

class GetTodayLastClocksUseCase {
  final ClockRepository repo;
  GetTodayLastClocksUseCase(this.repo);

  Future<Map<String, (DateTime?, bool)>> call(
    String companyId,
    DateTime from,
    DateTime to,
  ) async {
    final res = await repo.getLatestEntriesByCompanyInRange(companyId, from, to);
    if (!res.success) return {};
    final out = <String, (DateTime?, bool)>{};
    res.data.forEach((empId, record) {
      out[empId] = (record.clockIn, record.clockOut == null);
    });
    return out;
  }
}
