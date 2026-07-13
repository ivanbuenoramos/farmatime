import 'package:farmatime/data/models/clock_audit_log_model.dart';
import 'package:farmatime/domain/repositories/clock_repository.dart';

/// Devuelve el histórico completo e inmutable de auditoría de un fichaje,
/// ordenado de la entrada más antigua a la más reciente.
class GetClockAuditLogUseCase {
  final ClockRepository repository;

  GetClockAuditLogUseCase(this.repository);

  Future<List<ClockAuditLogModel>> call(String entryId) {
    return repository.getAuditLog(entryId);
  }
}
