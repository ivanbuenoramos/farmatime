import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/clock_in_out_model.dart';



abstract class ClockRepository {
  Future<Result<ClockInOutModel?>> createEntry(ClockInOutModel entry);
  Future<Result<ClockInOutModel?>> getCurrentEntry(String employeeId);
  Future<Result<List<ClockInOutModel>>> getEntriesByEmployee(String employeeId);
  Future<Result<ClockInOutModel?>> updateEntry(ClockInOutModel entry);
  Future<Result<Map<String, ClockInOutModel>>> getLatestEntriesByCompanyInRange(
    String companyId,
    DateTime from,
    DateTime to,
  );
}
