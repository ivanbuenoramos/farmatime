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
