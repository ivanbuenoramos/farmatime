import 'package:farmatime/data/models/clock_report.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/presentation/widgets/card/base_card.dart';
import 'package:farmatime/presentation/widgets/card/profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'clock_reports_controller.dart';

class ClockReportsPage extends GetView<ClockReportsController> {
  const ClockReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes de fichajes'),
        titleSpacing: 16,
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
        () => RefreshIndicator(
          onRefresh: controller.loadReportsForSelectedMonth,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MonthSelector(),
                const SizedBox(height: 16),
                _MonthSummaryCard(),
                const SizedBox(height: 16),
                if (controller.errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Get.theme.colorScheme.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        controller.errorMessage.value,
                        style: Get.textTheme.bodyMedium
                            ?.copyWith(color: Get.theme.colorScheme.error),
                      ),
                    ),
                  ),
                _EmployeesReportList(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// SELECTOR DE MES (chips horizontales)
// =====================================================================

class _MonthSelector extends GetView<ClockReportsController> {
  @override
  Widget build(BuildContext context) {
    return BaseCard(
      title: 'Mes del reporte',
      children: [
        SizedBox(
          height: 78,
          child: Obx(() {
            // Leemos los observables directamente en el cuerpo del Obx para
            // que GetX los registre (itemBuilder se ejecuta de forma lazy y
            // sus lecturas de .value no siempre quedan rastreadas).
            final selectedYear = controller.selectedYear.value;
            final selectedMonth = controller.selectedMonth.value;
            final months = controller.availableMonths;
            // Por defecto, scroll al mes seleccionado al renderizar.
            return ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: months.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final m = months[index];
                final isSelected =
                    m.year == selectedYear && m.month == selectedMonth;
                final now = DateTime.now();
                final isCurrent = m.year == now.year && m.month == now.month;

                return _MonthChip(
                  month: m,
                  isSelected: isSelected,
                  isCurrent: isCurrent,
                  onTap: () => controller.selectMonth(m),
                );
              },
            );
          }),
        ),
      ],
    );
  }
}

class _MonthChip extends StatelessWidget {
  final DateTime month;
  final bool isSelected;
  final bool isCurrent;
  final VoidCallback onTap;

  const _MonthChip({
    required this.month,
    required this.isSelected,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthShort =
        DateFormat.MMM('es_ES').format(month).replaceAll('.', '');
    final yearShort = DateFormat('y').format(month);

    final bgColor =
        isSelected ? theme.colorScheme.primary : theme.colorScheme.surface;
    final fgColor = isSelected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.secondary;
    final borderColor = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.outline;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 78,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              monthShort[0].toUpperCase() + monthShort.substring(1),
              style: theme.textTheme.titleSmall?.copyWith(
                color: fgColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              yearShort,
              style: theme.textTheme.bodySmall?.copyWith(
                color: fgColor.withOpacity(0.85),
              ),
            ),
            if (isCurrent)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isSelected ? fgColor : theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// CARD RESUMEN DEL MES
// =====================================================================

class _MonthSummaryCard extends GetView<ClockReportsController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final theme = Theme.of(context);
      final monthLabel = controller.monthLongLabel(
        controller.selectedYear.value,
        controller.selectedMonth.value,
      );

      return BaseCard(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.calendar_month_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      monthLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _MonthStatusBanner(),
                  ],
                ),
              ),
            ],
          ),
          if (!controller.isFutureMonth) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SummaryMetric(
                    icon: Icons.people_alt_outlined,
                    label: 'Con actividad',
                    value: '${controller.totalEmployeesWithActivity}',
                  ),
                ),
                Expanded(
                  child: _SummaryMetric(
                    icon: Icons.access_time_rounded,
                    label: 'Horas totales',
                    value: controller.totalHoursMonth.toStringAsFixed(1),
                  ),
                ),
                Expanded(
                  child: _SummaryMetric(
                    icon: Icons.picture_as_pdf_outlined,
                    label: 'PDFs',
                    value: '${controller.totalReports}',
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    });
  }
}

class _MonthStatusBanner extends GetView<ClockReportsController> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (controller.isFutureMonth) {
      return _StatusPill(
        icon: Icons.schedule_rounded,
        text: 'Mes futuro — aún no hay datos',
        color: theme.colorScheme.tertiary,
      );
    }

    if (controller.isCurrentMonth) {
      return _StatusPill(
        icon: Icons.autorenew_rounded,
        text: 'En curso · se cierra el día 1 del próximo mes',
        color: theme.colorScheme.primary,
      );
    }

    return _StatusPill(
      icon: Icons.check_circle_outline,
      text: 'Mes cerrado · partes generados',
      color: Colors.green.shade700,
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _StatusPill({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: Get.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.secondary,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// =====================================================================
// LISTA DE EMPLEADOS DEL MES
// =====================================================================

class _EmployeesReportList extends GetView<ClockReportsController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value && controller.reports.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Center(child: CircularProgressIndicator()),
        );
      }

      final rows = controller.rows;

      if (rows.isEmpty) {
        return BaseCard(
          children: [
            const SizedBox(height: 8),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.group_off_outlined,
                    size: 48,
                    color: Get.theme.colorScheme.tertiary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No hay empleados todavía',
                    style: Get.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      }

      return BaseCard(
        title: 'Empleados (${rows.length})',
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) => _EmployeeReportTile(row: rows[i]),
          ),
        ],
      );
    });
  }
}

class _EmployeeReportTile extends GetView<ClockReportsController> {
  final EmployeeMonthReportRow row;
  const _EmployeeReportTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final EmployeeModel emp = row.employee;
    final ClockReport? report = row.report;

    final canOpenPdf = report != null && row.hasActivity;

    return InkWell(
      onTap: canOpenPdf ? () => launchUrlString(report.downloadUrl) : null,
      borderRadius: BorderRadius.circular(10),
      child: Ink(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Row(
          children: [
            ProfileAvatar(
              imageUrl: emp.photoUrl,
              name: emp.name,
              colorValue: emp.avatarColor,
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    emp.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  _EmployeeReportSubtitle(report: report),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _EmployeeReportTrailing(
              report: report,
              hasActivity: row.hasActivity,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeReportSubtitle extends GetView<ClockReportsController> {
  final ClockReport? report;
  const _EmployeeReportSubtitle({required this.report});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (report == null || report!.recordsCount == 0) {
      // Sin reporte ni actividad
      if (controller.isCurrentMonth) {
        return Text(
          'Sin fichajes aún este mes',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.tertiary,
          ),
        );
      }
      if (controller.isFutureMonth) {
        return Text(
          '—',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.tertiary,
          ),
        );
      }
      return Text(
        'Sin actividad en este mes',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.tertiary,
        ),
      );
    }

    final r = report!;
    final hours = r.totalHours.toStringAsFixed(1);
    final days = r.daysCount;
    final updated = _relativeUpdated(r.updatedAt);

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _MiniBadge(
          icon: Icons.access_time_rounded,
          text: '$hours h',
        ),
        _MiniBadge(
          icon: Icons.calendar_today_rounded,
          text: '$days días',
        ),
        if (updated != null)
          Text(
            'Actualizado $updated',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.tertiary,
            ),
          ),
      ],
    );
  }

  String? _relativeUpdated(DateTime updatedAt) {
    final diff = DateTime.now().difference(updatedAt);
    if (diff.inSeconds < 60) return 'hace un momento';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'hace ${diff.inDays} d';
    return DateFormat('dd/MM/yyyy').format(updatedAt);
  }
}

class _EmployeeReportTrailing extends GetView<ClockReportsController> {
  final ClockReport? report;
  final bool hasActivity;
  const _EmployeeReportTrailing({
    required this.report,
    required this.hasActivity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (report != null && hasActivity) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.picture_as_pdf,
              size: 16,
              color: theme.colorScheme.onPrimary,
            ),
            const SizedBox(width: 4),
            Text(
              'PDF',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Icon(
      Icons.remove_circle_outline,
      size: 18,
      color: theme.colorScheme.tertiary,
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MiniBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.tertiary),
        const SizedBox(width: 4),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.secondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
