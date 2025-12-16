// lib/presentation/pages/clock_reports/clock_reports_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'clock_reports_controller.dart';

class ClockReportsPage extends GetView<ClockReportsController> {
  const ClockReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes de fichajes'),
        actions: [
          Obx(() => IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.isLoading.value
              ? null
              : controller.loadReportsForSelectedMonth,
            tooltip: 'Actualizar',
          )),
        ],
      ),
      body: Obx(
        () => Column(
          children: [
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildMonthSelector(theme),
            ),
            const SizedBox(height: 8),
            // Padding(
            //   padding: const EdgeInsets.symmetric(horizontal: 16),
            //   child: _buildActionsRow(theme),
            // ),
            // const SizedBox(height: 8),
            if (controller.errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  controller.errorMessage.value,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: _buildReportsList(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            value: controller.selectedMonth.value,
            decoration: const InputDecoration(
              labelText: 'Mes',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: List.generate(
              12,
              (index) {
                final month = index + 1;
                return DropdownMenuItem<int>(
                  value: month,
                  child: Text(
                    controller.monthName(month),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
            onChanged: (value) {
              if (value == null) return;
              controller.selectedMonth.value = value;
              controller.loadReportsForSelectedMonth();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<int>(
            value: controller.selectedYear.value,
            decoration: const InputDecoration(
              labelText: 'Año',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: controller.availableYears
                .map(
                  (y) => DropdownMenuItem<int>(
                    value: y,
                    child: Text(y.toString()),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              controller.selectedYear.value = value;
              controller.loadReportsForSelectedMonth();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionsRow(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: controller.isLoading.value
                ? null
                : controller.loadReportsForSelectedMonth,
            icon: controller.isLoading.value
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: const Text('Actualizar'),
          ),
        ),
        // const SizedBox(width: 12),
        // Expanded(
        //   child: FilledButton.icon(
        //     onPressed: controller.isGenerating.value
        //         ? null
        //         : controller.generateCurrentMonthToDate,
        //     style: FilledButton.styleFrom(
        //       backgroundColor: theme.colorScheme.primaryContainer,
        //       foregroundColor: theme.colorScheme.onPrimaryContainer,
        //     ),
        //     icon: controller.isGenerating.value
        //         ? const SizedBox(
        //             width: 16,
        //             height: 16,
        //             child: CircularProgressIndicator(strokeWidth: 2),
        //           )
        //         : const Icon(Icons.picture_as_pdf),
        //     label: const Text('Generar mes actual'),
        //   ),
        // ),
      ],
    );
  }

  Widget _buildReportsList(ThemeData theme) {
    if (controller.isLoading.value && controller.reports.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (controller.reports.isEmpty) {
      return const Center(
        child: Text('No hay reportes para este mes.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: controller.reports.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final report = controller.reports[index];
        return Card(
          elevation: 1,
          child: ListTile(
            title: Text(
              'Empleado: ${report.employeeId}',
              style: theme.textTheme.titleMedium,
            ),
            subtitle: Text(
              'Del ${_formatDate(report.periodStart)} al ${_formatDate(report.periodEnd)}\n'
              'Total horas: ${report.totalHours.toStringAsFixed(2)}   '
              'Días: ${report.daysCount}',
            ),
            isThreeLine: true,
            trailing: IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: () {
                launchUrlString(report.downloadUrl);
              },
              tooltip: 'Ver PDF',
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}