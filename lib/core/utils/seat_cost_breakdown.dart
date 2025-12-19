class SeatCostBreakdown {
  final int nowSubtotalCents;
  final int nowTaxCents;
  final int nowTotalCents;

  final int nextSubtotalCents;
  final int nextTaxCents;
  final int nextTotalCents;

  final double prorationFraction;

  const SeatCostBreakdown({
    required this.nowSubtotalCents,
    required this.nowTaxCents,
    required this.nowTotalCents,
    required this.nextSubtotalCents,
    required this.nextTaxCents,
    required this.nextTotalCents,
    required this.prorationFraction,
  });
}

int _roundCents(num v) => v.round();

SeatCostBreakdown estimateSeatCosts({
  required int currentTotalSeats, // incluye la gratis
  required int newTotalSeats, // incluye la gratis
  required DateTime periodStart,
  required DateTime periodEnd,
  DateTime? now,
  required int unitMonthlyCents, // 100 = 1,00€ por plaza/mes (sin IVA)
  required double taxRate, // 0.21
}) {
  final tNow = now ?? DateTime.now();

  final currentPaid = (currentTotalSeats - 1).clamp(0, 999999);
  final newPaid = (newTotalSeats - 1).clamp(0, 999999);
  final deltaPaid = newPaid - currentPaid;

  // Próxima mensualidad (full mensual con nueva cantidad)
  final nextSubtotal = newPaid * unitMonthlyCents;
  final nextTax = _roundCents(nextSubtotal * taxRate);
  final nextTotal = nextSubtotal + nextTax;

  // Si no sube plazas: hoy = 0
  if (deltaPaid <= 0) {
    return SeatCostBreakdown(
      nowSubtotalCents: 0,
      nowTaxCents: 0,
      nowTotalCents: 0,
      nextSubtotalCents: nextSubtotal,
      nextTaxCents: nextTax,
      nextTotalCents: nextTotal,
      prorationFraction: 0,
    );
  }

  final startMs = periodStart.millisecondsSinceEpoch;
  final endMs = periodEnd.millisecondsSinceEpoch;
  final nowMs = tNow.millisecondsSinceEpoch;

  final cycleMs = (endMs - startMs).clamp(1, 1 << 62);
  final remainingMs = (endMs - nowMs).clamp(0, cycleMs);

  final fraction = remainingMs / cycleMs;

  final nowSubtotal = _roundCents(deltaPaid * unitMonthlyCents * fraction);
  final nowTax = _roundCents(nowSubtotal * taxRate);
  final nowTotal = nowSubtotal + nowTax;

  return SeatCostBreakdown(
    nowSubtotalCents: nowSubtotal,
    nowTaxCents: nowTax,
    nowTotalCents: nowTotal,
    nextSubtotalCents: nextSubtotal,
    nextTaxCents: nextTax,
    nextTotalCents: nextTotal,
    prorationFraction: fraction,
  );
}