// lib/domain/entities/clock_report.dart
class ClockReport {
  final String id;
  final String companyId;
  final String employeeId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String pdfPath;
  final String downloadUrl;
  final double totalHours;
  final int daysCount;
  final String source;
  final DateTime createdAt;

  const ClockReport({
    required this.id,
    required this.companyId,
    required this.employeeId,
    required this.periodStart,
    required this.periodEnd,
    required this.pdfPath,
    required this.downloadUrl,
    required this.totalHours,
    required this.daysCount,
    required this.source,
    required this.createdAt,
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