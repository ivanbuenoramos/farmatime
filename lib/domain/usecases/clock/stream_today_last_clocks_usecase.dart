// lib/domain/usecases/clock/stream_today_last_clocks_usecase.dart
import 'package:farmatime/domain/repositories/clock_repository.dart';

class StreamTodayLastClocksUseCase {
  StreamTodayLastClocksUseCase(this._repo);
  final ClockRepository _repo;

  Stream<Map<String, (DateTime? lastClockIn, bool isActive)>> call(
    String companyId,
    DateTime from,
    DateTime to, {
    List<String>? employeeIds,
  }) {
    return _repo.streamTodayLastClocks(companyId, from, to, employeeIds: employeeIds);
  }
}