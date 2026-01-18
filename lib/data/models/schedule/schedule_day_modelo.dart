import 'package:farmatime/data/models/schedule/day_entry.dart';

class ScheduleDayModel {
  final String companyId;
  final String employeeId;
  final String date; // yyyy-MM-dd
  final DayEntry entry;

  const ScheduleDayModel({
    required this.companyId,
    required this.employeeId,
    required this.date,
    required this.entry,
  });
}