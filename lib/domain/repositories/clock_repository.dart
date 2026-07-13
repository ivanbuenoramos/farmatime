import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/clock_in_out_model.dart';
import 'package:farmatime/data/models/clock_audit_log_model.dart';



abstract class ClockRepository {
  Future<Result<ClockInOutModel?>> createEntry(ClockInOutModel entry);
  Future<Result<ClockInOutModel?>> getCurrentEntry(String employeeId);
  Future<Result<List<ClockInOutModel>>> getEntriesByEmployee(String employeeId);
  Future<Result<ClockInOutModel?>> updateEntry(ClockInOutModel entry);

  /// Actualiza un fichaje y registra el cambio en el log de auditoría
  /// inmutable, todo dentro de una misma transacción de Firestore.
  ///
  /// El [auditLog] describe quién, cuándo, por qué y qué cambió (antes/después).
  /// Si la transacción falla, ni el fichaje ni el log se modifican.
  Future<Result<ClockInOutModel?>> updateEntryWithAudit({
    required ClockInOutModel entry,
    required ClockAuditLogModel auditLog,
  });

  /// Registra la entrada de auditoría de la creación de un fichaje (estado
  /// inicial del histórico). Es best-effort: no debe bloquear el fichaje.
  Future<void> logCreation(ClockAuditLogModel auditLog);

  /// Devuelve el histórico completo de auditoría de un fichaje, ordenado
  /// cronológicamente (de más antiguo a más reciente).
  Future<List<ClockAuditLogModel>> getAuditLog(String entryId);
  Future<Result<Map<String, ClockInOutModel>>> getLatestEntriesByCompanyInRange(
    String companyId,
    DateTime from,
    DateTime to,
  );
  
  Future<List<ClockInOutModel>> getClockRecords({
    required String companyId,
    required DateTime from,
    required DateTime to,
    String? employeeId,
  });

  Future<List<ClockInOutModel>> getClockRecordsForEmployeeDay({
    required String companyId,
    required String employeeId,
    required DateTime day,
  });

  Stream<List<ClockInOutModel>> streamClockRecords({
    required String companyId,
    required DateTime from,
    required DateTime to,
    String? employeeId,
  });

  Stream<Map<String, (DateTime? lastClockIn, bool isActive)>> streamTodayLastClocks(
    String companyId,
    DateTime from,
    DateTime to, {
    List<String>? employeeIds,
  });
}
