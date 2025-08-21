import 'package:flutter/material.dart';

class WeekdaySelector extends StatelessWidget {
  const WeekdaySelector({super.key, required this.value, required this.onChanged});
  final Set<int> value; // 1..7
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = [
      {'d': 1, 't': 'L'},
      {'d': 2, 't': 'M'},
      {'d': 3, 't': 'X'},
      {'d': 4, 't': 'J'},
      {'d': 5, 't': 'V'},
      {'d': 6, 't': 'S'},
      {'d': 7, 't': 'D'},
    ];
    return Wrap(
      spacing: 6,
      children: labels.map((m) {
        final d = m['d'] as int;
        final selected = value.contains(d);
        return ChoiceChip(
          label: Text(m['t'] as String),
          selected: selected,
          onSelected: (_) => onChanged(d),
        );
      }).toList(),
    );
  }
}