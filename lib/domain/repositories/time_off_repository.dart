import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/schedule/time_off_model.dart';

/// Solapamiento detectado: para un día concreto, qué empleados ya tienen
/// vacaciones / asuntos propios (aprobados o pendientes) en esa misma fecha.
class TimeOffOverlap {
  final String date; // yyyy-MM-dd
  final String employeeId;
  final String employeeName;
  final TimeOffType type;
  final TimeOffStatus status;

  const TimeOffOverlap({
    required this.date,
    required this.employeeId,
    required this.employeeName,
    required this.type,
    required this.status,
  });
}

abstract class TimeOffRepository {
  /// Crea una nueva solicitud (estado requested). Devuelve el id del documento.
  Future<Result<String>> create(TimeOffModel request);

  /// Solicitudes de un empleado concreto (real-time), más recientes primero.
  Stream<List<TimeOffModel>> streamByEmployee({
    required String companyId,
    required String employeeId,
  });

  /// Todas las solicitudes de la empresa (real-time), más recientes primero.
  Stream<List<TimeOffModel>> streamByCompany({
    required String companyId,
  });

  /// La empresa aprueba la solicitud tal cual.
  /// Al aprobar, marca los días en el calendario del empleado.
  Future<Result<bool>> companyApprove({
    required TimeOffModel request,
    required String decidedBy,
  });

  /// La empresa rechaza la solicitud.
  Future<Result<bool>> companyReject({
    required TimeOffModel request,
    required String decidedBy,
    String? companyNote,
  });

  /// La empresa propone fechas alternativas (estado proposed).
  Future<Result<bool>> companyPropose({
    required TimeOffModel request,
    required List<String> proposedDates,
    required String decidedBy,
    String? companyNote,
  });

  /// El empleado acepta la propuesta de la empresa (queda aprobada y se marca el calendario).
  Future<Result<bool>> employeeAcceptProposal({
    required TimeOffModel request,
    required String decidedBy,
  });

  /// El empleado rechaza la propuesta de la empresa (queda rechazada).
  Future<Result<bool>> employeeRejectProposal({
    required TimeOffModel request,
    required String decidedBy,
  });

  /// El empleado cancela su propia solicitud mientras sigue pendiente
  /// (requested o proposed). Queda en estado cancelled.
  Future<Result<bool>> employeeCancel({
    required TimeOffModel request,
    required String decidedBy,
  });

  /// Solapamientos con otros empleados para un conjunto de fechas.
  /// Excluye al propio empleado de la solicitud.
  Future<Result<List<TimeOffOverlap>>> findOverlaps({
    required String companyId,
    required String excludeEmployeeId,
    required List<String> dates,
  });
}
