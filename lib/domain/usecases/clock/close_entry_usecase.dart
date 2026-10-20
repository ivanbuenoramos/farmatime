import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/clock_repository.dart';

/// Cierre del fichaje abierto por el propio empleado (solo campos de salida).
class CloseEntryUseCase {
  final ClockRepository repository;

  CloseEntryUseCase(this.repository);

  Future<Result<void>> call({
    required String entryId,
    required DateTime clockOut,
    double? clockOutLat,
    double? clockOutLng,
  }) {
    return repository.closeEntry(
      entryId: entryId,
      clockOut: clockOut,
      clockOutLat: clockOutLat,
      clockOutLng: clockOutLng,
    );
  }
}
