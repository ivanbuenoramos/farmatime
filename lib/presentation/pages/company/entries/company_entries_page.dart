import 'package:farmatime/presentation/pages/company/entries/company_entries_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class CompanyEntriesPage extends GetView<CompanyEntriesController> {
  const CompanyEntriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Control de fichajes')),
      body: Obx(() {
        return RefreshIndicator(
          onRefresh: controller.fetchRecords,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _FiltersCard(controller: controller),
              const SizedBox(height: 16),
              _RecordsCard(controller: controller),
              if (controller.errorText.value != null) ...[
                const SizedBox(height: 12),
                Text(
                  controller.errorText.value!,
                  style: theme.textTheme.bodyMedium!
                      .copyWith(color: theme.colorScheme.error),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }
}

class _FiltersCard extends StatelessWidget {
  const _FiltersCard({required this.controller});
  final CompanyEntriesController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final df = DateFormat('d/M/yy');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filtros', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'Desde',
                    valueBuilder: () => controller.from.value,
                    onPick: (picked) =>
                        controller.setRange(picked, controller.to.value),
                    df: df,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateField(
                    label: 'Hasta',
                    valueBuilder: () => controller.to.value,
                    onPick: (picked) =>
                        controller.setRange(controller.from.value, picked),
                    df: df,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _EmployeeDropdown(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.valueBuilder,
    required this.onPick,
    required this.df,
  });

  final String label;
  final DateTime Function() valueBuilder;
  final Future<void> Function(DateTime) onPick;
  final DateFormat df;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = valueBuilder();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value,
              firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
            );
            if (picked != null) await onPick(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(child: Text(df.format(value))),
                const Icon(Icons.calendar_month),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmployeeDropdown extends StatelessWidget {
  const _EmployeeDropdown({required this.controller});
  final CompanyEntriesController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Empleados', style: theme.textTheme.labelMedium),
        const SizedBox(height: 6),
        Obx(() {
          final items = <DropdownMenuItem<String?>>[
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Todos'),
            ),
            ...controller.employees.map(
              (e) => DropdownMenuItem<String?>(
                value: e.id,
                child: Text(e.name),
              ),
            )
          ];

          return DropdownButtonFormField<String?>(
            value: controller.selectedEmployeeId.value,
            items: items,
            onChanged: (val) => controller.setEmployee(val),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.arrow_drop_down_rounded),
          );
        }),
      ],
    );
  }
}

class _RecordsCard extends StatelessWidget {
  const _RecordsCard({required this.controller});
  final CompanyEntriesController controller;

  String _fmtDay(DateTime d) => DateFormat('d/M/yy').format(d);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Obx(() {
          final loading = controller.isLoading.value;
          final rows = controller.rows;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fichajes', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              if (loading) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 24),
              ] else if (rows.isEmpty) ...[
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'No hay fichajes en este rango.',
                    style: theme.textTheme.bodyMedium!
                        .copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 8),
              ] else
                _RecordsTable(rows: rows, fmtDay: _fmtDay),
            ],
          );
        }),
      ),
    );
  }
}

class _RecordsTable extends StatelessWidget {
  const _RecordsTable({required this.rows, required this.fmtDay});

  final List<ClockRowView> rows;
  final String Function(DateTime) fmtDay;

  @override
  Widget build(BuildContext context) {
    // DataTable funciona mejor con SingleChildScrollView horizontal
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 44,
        dataRowMaxHeight: 56,
        columns: const [
          DataColumn(label: Text('Día')),
          DataColumn(label: Text('Empleado')),
          DataColumn(label: Text('Fichajes')),
          DataColumn(label: Text('Prev.')),
          DataColumn(label: Text('Trab.')),
          DataColumn(label: Text('Dif.')),
        ],
        rows: rows.map((r) => _toRow(context, r)).toList(),
      ),
    );
  }

  DataRow _toRow(BuildContext context, ClockRowView r) {
    final theme = Theme.of(context);
    final diff = r.diffMinutes;
    final diffColor = diff >= 0
        ? theme.colorScheme.primary
        : theme.colorScheme.error;

    return DataRow(
      cells: [
        DataCell(Text(fmtDay(r.day))),
        DataCell(Text(r.employeeName)),
        DataCell(_RangePill(text: r.rangeText)),
        DataCell(Text(r.expectedHhMm)),
        DataCell(Text(r.workedHhMm)),
        DataCell(
          Text(
            r.diffSigned,
            style: theme.textTheme.bodyMedium!
                .copyWith(color: diffColor, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _RangePill extends StatelessWidget {
  const _RangePill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(text, style: theme.textTheme.bodySmall),
    );
  }
}
