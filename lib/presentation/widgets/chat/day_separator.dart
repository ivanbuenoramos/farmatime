import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DaySeparator extends StatelessWidget {
  final DateTime day;
  const DaySeparator({super.key, required this.day});

  String _label(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final target = DateTime(d.year, d.month, d.day);

    if (target == today) return 'Hoy';
    if (target == yesterday) return 'Ayer';
    if (now.year == d.year) {
      return DateFormat('EEEE d MMM', 'es_ES').format(d);
    }
    return DateFormat('d MMM yyyy', 'es_ES').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: theme.colorScheme.outline.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _label(day),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.w600,
              fontSize: 11.5,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
