// lib/data/models/clock_report.dart
class ClockReport {
  final String id;
  final String companyId;
  final String employeeId;
  final int? year;
  final int? month;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String pdfPath;
  final String downloadUrl;
  final double totalHours;
  final int daysCount;
  final int recordsCount;
  final String source;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ClockReport({
    required this.id,
    required this.companyId,
    required this.employeeId,
    required this.year,
    required this.month,
    required this.periodStart,
    required this.periodEnd,
    required this.pdfPath,
    required this.downloadUrl,
    required this.totalHours,
    required this.daysCount,
    required this.recordsCount,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });
}

class ClockReportPage {
  final List<ClockReport> items;
  final DateTime? lastPeriodStart;
  final bool hasMore;

  const ClockReportPage({
    required this.items,
    required this.lastPeriodStart,
    required this.hasMore,
  });
}
