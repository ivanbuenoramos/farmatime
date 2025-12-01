// lib/data/repositories/clock_report_repository_impl.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:farmatime/data/models/clock_report.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';

import '../../domain/repositories/clock_report_repository.dart';

class ClockReportRepositoryImpl implements ClockReportRepository {
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  ClockReportRepositoryImpl({
    FirebaseFirestore? firestoreInstance,
    FirebaseFunctions? functionsInstance,
  })  : firestore = firestoreInstance ?? FirebaseFirestore.instance,
        functions = functionsInstance ?? FirebaseFunctions.instanceFor(
          app: Firebase.app(),
          region: 'europe-west1',
        );

  static const _collection = 'clockReports';

  ClockReport _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ClockReport(
      id: doc.id,
      companyId: data['companyId'] as String? ?? '',
      employeeId: data['employeeId'] as String? ?? '',
      periodStart: DateTime.parse(data['periodStart'] as String),
      periodEnd: DateTime.parse(data['periodEnd'] as String),
      pdfPath: data['pdfPath'] as String? ?? '',
      downloadUrl: data['downloadUrl'] as String? ?? '',
      totalHours: (data['totalHours'] as num?)?.toDouble() ?? 0.0,
      daysCount: (data['daysCount'] as num?)?.toInt() ?? 0,
      source: data['source'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  /// 1) Lista de reportes de una farmacia por mes
  @override
  Future<List<ClockReport>> getCompanyReportsByMonth({
    required String companyId,
    required int year,
    required int month,
  }) async {
    // periodStart/periodEnd se guardaron como ISO string en la función.
    final monthStart = DateTime(year, month, 1);
    final nextMonthStart =
        (month == 12) ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);

    final startIso = monthStart.toUtc().toIso8601String();
    final endIso = nextMonthStart.toUtc().toIso8601String();

    final snap = await firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('periodStart', isGreaterThanOrEqualTo: startIso)
        .where('periodStart', isLessThan: endIso)
        .orderBy('periodStart', descending: false)
        .get();


    return snap.docs.map(_fromDoc).toList();
  }

  /// 2) Generar reportes del día 1 de mes actual hasta hoy
  @override
  Future<void> generateCurrentMonthToDateReports({
    required String companyId,
  }) async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final dateFormatter = DateFormat('yyyy-MM-dd');

    final startStr = dateFormatter.format(monthStart);
    final endStr = dateFormatter.format(now);

    final callable = functions.httpsCallable('reportsGenerateRange');

    final result = await callable.call(<String, dynamic>{
      'companyId': companyId,
      'startDate': startStr,
      'endDate': endStr,
    });
    print('reportsGenerateRange result: ${result.data}');
  }

  /// 3) Reportes de un empleado paginados de 10 en 10
  @override
  Future<ClockReportPage> getEmployeeReportsPaginated({
    required String companyId,
    required String employeeId,
    DateTime? startAfterPeriodStart,
    int pageSize = 10,
  }) async {
    Query<Map<String, dynamic>> query = firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('employeeId', isEqualTo: employeeId)
        // ordenamos por periodStart (ISO string, orden lexicográfico = cronológico)
        .orderBy('periodStart', descending: true)
        .limit(pageSize);

    if (startAfterPeriodStart != null) {
      final cursorIso = startAfterPeriodStart.toUtc().toIso8601String();
      query = query.startAfter(<String>[cursorIso]);
    }

    final snap = await query.get();
    final items = snap.docs.map(_fromDoc).toList();

    DateTime? nextCursor;
    if (items.isNotEmpty && items.length == pageSize) {
      // Último periodStart como cursor
      nextCursor = items.last.periodStart;
    }

    return ClockReportPage(
      items: items,
      lastPeriodStart: nextCursor,
      hasMore: nextCursor != null,
    );
  }
}