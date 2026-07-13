import 'package:meta/meta.dart';
import '../../data/models/employee_model.dart';
import '../../data/models/schedule/time_off_model.dart';

/// Resultado del cálculo simple (sin solicitudes)
class SimpleLeaveBalances {
  final double vacationEarned;   // días devengados de vacaciones
  final double personalEarned;   // días devengados de asuntos propios
  final double vacationAvailable; // = vacationEarned (no hay usados aún)
  final double personalAvailable; // = personalEarned (no hay usados aún)
  final DateTime asOf;            // fecha del cálculo
  final DateTime hireDateUsed;    // fecha base empleada para el cómputo

  const SimpleLeaveBalances({
    required this.vacationEarned,
    required this.personalEarned,
    required this.vacationAvailable,
    required this.personalAvailable,
    required this.asOf,
    required this.hireDateUsed,
  });
}

/// Normaliza fecha a UTC sin hora para evitar errores por zonas/horas.
DateTime _stripTime(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// Días naturales entre start y end, ambos inclusive.
/// Si prefieres “hasta ayer”, resta 1 a este resultado al usarlo.
int _diffDaysInclusive(DateTime start, DateTime end) {
  final s = _stripTime(start);
  final e = _stripTime(end);
  return (e.difference(s).inDays + 1).clamp(0, 1000000);
}

double _round2(num v) => double.parse(v.toStringAsFixed(2));

/// Calcula días devengados por tiempo trabajado.
/// - Vacaciones: prorrateo diario desde hireDate usando vacationDaysPer30/30
/// - AP: prorrateo diario desde hireDate usando personalDaysPerYear/365
///
/// [hireDateOverride] te permite pasar la fecha real de alta.
/// Si es null, usa employee.createdAt como fallback.
@visibleForTesting
({double vacationEarned, double personalEarned}) computeEarnedByTime({
  required EmployeeModel employee,
  DateTime? hireDateOverride,
  DateTime? today,
}) {
  final now = today ?? DateTime.now();
  final hireDate = hireDateOverride ?? employee.createdAt;

  // Si quieres “hasta ayer” en lugar de incluir hoy:
  // final daysWorked = (_diffDaysInclusive(hireDate, now) - 1).clamp(0, 1000000);
  final daysWorked = _diffDaysInclusive(hireDate, now);

  final vacationEarned =
      (employee.vacationDaysPer30 / 30.0) * daysWorked; // días/30 → por día
  final personalEarned =
      (employee.personalDaysPerYear / 365.0) * daysWorked; // días/año → por día

  return (
    vacationEarned: _round2(vacationEarned),
    personalEarned: _round2(personalEarned),
  );
}

/// Versión pública del cálculo de devengado (vacaciones y asuntos propios)
/// por tiempo trabajado. Pensada para usarse fuera de tests.
({double vacationEarned, double personalEarned}) earnedByTime({
  required EmployeeModel employee,
  DateTime? hireDateOverride,
  DateTime? today,
}) =>
    computeEarnedByTime(
      employee: employee,
      hireDateOverride: hireDateOverride,
      today: today,
    );

/// API principal para tu app hoy: devuelve devengado y disponible (sin usados).
SimpleLeaveBalances computeSimpleBalances({
  required EmployeeModel employee,
  DateTime? hireDateOverride,
  DateTime? today,
}) {
  final now = today ?? DateTime.now();
  final hireDate = hireDateOverride ?? employee.createdAt;

  final earned = computeEarnedByTime(
    employee: employee,
    hireDateOverride: hireDate,
    today: now,
  );

  // Como aún no hay solicitudes, “usado = 0”, por tanto disponible = devengado.
  return SimpleLeaveBalances(
    vacationEarned: earned.vacationEarned,
    personalEarned: earned.personalEarned,
    vacationAvailable: earned.vacationEarned,
    personalAvailable: earned.personalEarned,
    asOf: now,
    hireDateUsed: hireDate,
  );
}

/// Igual que [computeSimpleBalances] pero descontando del disponible los días
/// ya aprobados (vacaciones y asuntos propios) presentes en [requests].
///
/// Solo cuentan las solicitudes en estado approved; se usan las fechas
/// efectivas (las propuestas por la empresa si las hubo).
SimpleLeaveBalances computeBalancesWithRequests({
  required EmployeeModel employee,
  required List<TimeOffModel> requests,
  DateTime? hireDateOverride,
  DateTime? today,
}) {
  final base = computeSimpleBalances(
    employee: employee,
    hireDateOverride: hireDateOverride,
    today: today,
  );

  var vacationUsed = 0;
  var personalUsed = 0;
  for (final r in requests) {
    if (r.status != TimeOffStatus.approved) continue;
    final days = r.effectiveDates.length;
    if (r.type == TimeOffType.vacation) {
      vacationUsed += days;
    } else {
      personalUsed += days;
    }
  }

  double clampNonNeg(double v) => v < 0 ? 0 : v;

  return SimpleLeaveBalances(
    vacationEarned: base.vacationEarned,
    personalEarned: base.personalEarned,
    vacationAvailable: clampNonNeg(_round2(base.vacationEarned - vacationUsed)),
    personalAvailable: clampNonNeg(_round2(base.personalEarned - personalUsed)),
    asOf: base.asOf,
    hireDateUsed: base.hireDateUsed,
  );
}