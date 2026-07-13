import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/schedule/time_off_model.dart';
import 'package:farmatime/domain/repositories/time_off_repository.dart';

/// Decisiones sobre una solicitud, tanto de la empresa como del empleado.
class DecideTimeOffUseCase {
  final TimeOffRepository repo;
  DecideTimeOffUseCase(this.repo);

  Future<Result<bool>> companyApprove({
    required TimeOffModel request,
    required String decidedBy,
  }) =>
      repo.companyApprove(request: request, decidedBy: decidedBy);

  Future<Result<bool>> companyReject({
    required TimeOffModel request,
    required String decidedBy,
    String? companyNote,
  }) =>
      repo.companyReject(
        request: request,
        decidedBy: decidedBy,
        companyNote: companyNote,
      );

  Future<Result<bool>> companyPropose({
    required TimeOffModel request,
    required List<String> proposedDates,
    required String decidedBy,
    String? companyNote,
  }) =>
      repo.companyPropose(
        request: request,
        proposedDates: proposedDates,
        decidedBy: decidedBy,
        companyNote: companyNote,
      );

  Future<Result<bool>> employeeAcceptProposal({
    required TimeOffModel request,
    required String decidedBy,
  }) =>
      repo.employeeAcceptProposal(request: request, decidedBy: decidedBy);

  Future<Result<bool>> employeeRejectProposal({
    required TimeOffModel request,
    required String decidedBy,
  }) =>
      repo.employeeRejectProposal(request: request, decidedBy: decidedBy);

  Future<Result<bool>> employeeCancel({
    required TimeOffModel request,
    required String decidedBy,
  }) =>
      repo.employeeCancel(request: request, decidedBy: decidedBy);
}
