import 'package:farmatime/data/models/clock_in_out_model.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/clock_repository.dart';

class GetEntriesByEmployeeUseCase {
  final ClockRepository repository;

  GetEntriesByEmployeeUseCase(this.repository);

  Future<Result<List<ClockInOutModel>>> call(String employeeId, {String? companyId}) {
    return repository.getEntriesByEmployee(employeeId, companyId: companyId);
  }
}