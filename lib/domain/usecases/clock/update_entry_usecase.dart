import 'package:farmatime/data/models/clock_in_out_model.dart';
import 'package:farmatime/data/models/clock_audit_log_model.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/clock_repository.dart';

class UpdateEntryUseCase {
  final ClockRepository repository;

  UpdateEntryUseCase(this.repository);

  /// Actualiza un fichaje. Si se aporta [auditLog], el cambio se registra en
  /// el log inmutable de auditoría dentro de la misma transacción (uso normal
  /// en ediciones, obligatorio por normativa). Sin [auditLog] se comporta como
  /// una actualización simple (uso interno del lado del empleado al fichar).
  Future<Result<ClockInOutModel?>> call(
    ClockInOutModel entry, {
    ClockAuditLogModel? auditLog,
  }) {
    if (auditLog != null) {
      return repository.updateEntryWithAudit(entry: entry, auditLog: auditLog);
    }
    return repository.updateEntry(entry);
  }
}
