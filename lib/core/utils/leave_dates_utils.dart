// Utilidades para trabajar con fechas de solicitudes (vacaciones / asuntos propios).
// Las fechas se manejan como cadenas 'yyyy-MM-dd' para coincidir con el resto
// del esquema de Firestore (overrides de calendario, etc.).

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Expande un rango inclusivo [start, end] a la lista de días 'yyyy-MM-dd'.
List<String> expandRange(DateTime start, DateTime end) {
  var s = _dateOnly(start);
  final e = _dateOnly(end);
  final a = s.isBefore(e) ? s : e;
  final b = s.isBefore(e) ? e : s;

  final out = <String>[];
  var cur = a;
  while (!cur.isAfter(b)) {
    out.add(ymd(cur));
    cur = cur.add(const Duration(days: 1));
  }
  return out;
}

/// Normaliza una lista de DateTime a 'yyyy-MM-dd' ordenadas y sin duplicados.
List<String> daysToYmd(Iterable<DateTime> days) {
  final set = <String>{...days.map((d) => ymd(_dateOnly(d)))};
  final list = set.toList()..sort();
  return list;
}

/// Ordena y deduplica una lista de cadenas 'yyyy-MM-dd'.
List<String> normalizeDates(Iterable<String> dates) {
  final set = <String>{...dates};
  final list = set.toList()..sort();
  return list;
}

/// Resumen legible de una lista de fechas: "3 días · 12/05 – 14/05" o
/// "2 días · 12/05, 18/05".
String formatDatesSummary(List<String> dates) {
  if (dates.isEmpty) return '—';
  final sorted = normalizeDates(dates);
  final parsed = sorted.map(DateTime.parse).toList();

  String dm(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  // ¿es un rango contiguo?
  bool contiguous = true;
  for (var i = 1; i < parsed.length; i++) {
    if (parsed[i].difference(parsed[i - 1]).inDays != 1) {
      contiguous = false;
      break;
    }
  }

  final count = '${dates.length} día${dates.length == 1 ? '' : 's'}';
  if (parsed.length == 1) return '$count · ${dm(parsed.first)}';
  if (contiguous) return '$count · ${dm(parsed.first)} – ${dm(parsed.last)}';
  return '$count · ${parsed.map(dm).join(', ')}';
}
