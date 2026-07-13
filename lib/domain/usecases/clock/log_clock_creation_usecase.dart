import 'package:farmatime/data/models/clock_audit_log_model.dart';
import 'package:farmatime/domain/repositories/clock_repository.dart';

/// Registra la entrada de auditoría de la creación de un fichaje (estado
/// inicial del histórico). Best-effort: no debe bloquear el fichaje.
class LogClockCreationUseCase {
  final ClockRepository repository;

  LogClockCreationUseCase(this.repository);

  Future<void> call(ClockAuditLogModel auditLog) {
    return repository.logCreation(auditLog);
  }
}
