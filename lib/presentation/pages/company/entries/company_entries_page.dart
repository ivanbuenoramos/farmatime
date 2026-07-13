import 'package:farmatime/presentation/pages/company/entries/company_entries_controller.dart';
import 'package:farmatime/presentation/widgets/card/base_card.dart';
import 'package:farmatime/presentation/widgets/card/payment_issue_alert_card.dart';
import 'package:farmatime/presentation/widgets/card/profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class CompanyEntriesPage extends GetView<CompanyEntriesController> {
  const CompanyEntriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Control de fichajes'),
        titleSpacing: 16,
        actions: [
          IconButton(
            tooltip: 'Ver reportes',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: controller.redirectToReportsPage,
          ),
        ],
      ),
      body: Obx(() {
        final company = controller.brain.company.value;
        final billingStatus = company?.billingStatus;
        final showBillingAlert =
            billingStatus != null && billingStatus != 'active' && billingStatus != 'none';

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            if (showBillingAlert) ...[
              PaymentIssueAlertCard(billingStatus: billingStatus),
              const SizedBox(height: 12),
            ],
            const _FiltersCard(),
            const SizedBox(height: 12),
            const _SummaryCard(),
            const SizedBox(height: 12),
            const _RecordsCard(),
            if (controller.errorText.value != null) ...[
              const SizedBox(height: 12),
              _ErrorBanner(message: controller.errorText.value!),
            ],
          ],
        );
      }),
    );
  }
}

// =====================================================================
// TARJETA DE RESUMEN
// =====================================================================

class _SummaryCard extends GetView<CompanyEntriesController> {
  const _SummaryCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dfRange = DateFormat('d MMM', 'es_ES');

    return Obx(() {
      final rows = controller.rows;
      final totalMinutes =
          rows.fold<int>(0, (acc, r) => acc + r.workedMinutes);
      final employeesWithActivity =
          rows.map((r) => r.employeeName).toSet().length;

      final rangeLabel =
          '${dfRange.format(controller.from.value)} – ${dfRange.format(controller.to.value)}';

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
                  Icons.fact_check_outlined,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumen del periodo',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rangeLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.tertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.access_time_rounded,
                  label: 'Horas trab.',
                  value: _formatHours(totalMinutes),
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.fingerprint_rounded,
                  label: 'Fichajes',
                  value: '${rows.length}',
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.people_alt_outlined,
                  label: 'Empleados',
                  value: '$employeesWithActivity',
                ),
              ),
            ],
          ),
        ],
      );
    });
  }

  static String _formatHours(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

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
// FILTROS
// =====================================================================

class _FiltersCard extends GetView<CompanyEntriesController> {
  const _FiltersCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Obx(() {
          final lockedFreePlan =
              !controller.isBillingActive && controller.employees.isNotEmpty;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Expanded(child: _DateRangeField()),
                  SizedBox(width: 8),
                  Expanded(child: _EmployeeDropdown()),
                ],
              ),
              if (lockedFreePlan)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 14,
                        color: theme.colorScheme.tertiary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'En el plan gratuito solo puedes ver los fichajes del primer empleado.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.tertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _DateRangeField extends GetView<CompanyEntriesController> {
  const _DateRangeField();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final df = DateFormat('d MMM', 'es_ES');
    final from = controller.from.value;
    final to = controller.to.value;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final picked = await showDateRangePicker(
          context: context,
          initialDateRange: DateTimeRange(start: from, end: to),
          firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
        );
        if (picked != null) {
          await controller.setRange(picked.start, picked.end);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_month_rounded,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${df.format(from)} – ${df.format(to)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeDropdown extends GetView<CompanyEntriesController> {
  const _EmployeeDropdown();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      final isBillingActive = controller.isBillingActive;
      final employees = controller.employees;
      final selected = controller.selectedEmployeeIds;

      final String label;
      if (!isBillingActive) {
        label = employees.isNotEmpty ? employees.first.name : 'Empleado';
      } else if (selected.isEmpty) {
        label = 'Todos los empleados';
      } else if (selected.length == 1) {
        final e = employees.firstWhereOrNull((e) => e.uid == selected.first);
        label = e?.name ?? '1 empleado';
      } else {
        label = '${selected.length} empleados';
      }

      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isBillingActive
            ? () => _openSelector(context)
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: isBillingActive
                ? null
                : theme.colorScheme.outline.withOpacity(0.08),
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.people_alt_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.arrow_drop_down_rounded,
                color: theme.colorScheme.tertiary,
              ),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _openSelector(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EmployeeMultiSelectSheet(controller: controller),
    );
  }
}

/// Bottom sheet con checkboxes para seleccionar varios empleados.
class _EmployeeMultiSelectSheet extends StatefulWidget {
  const _EmployeeMultiSelectSheet({required this.controller});
  final CompanyEntriesController controller;

  @override
  State<_EmployeeMultiSelectSheet> createState() =>
      _EmployeeMultiSelectSheetState();
}

class _EmployeeMultiSelectSheetState extends State<_EmployeeMultiSelectSheet> {
  late final Set<String> _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.controller.selectedEmployeeIds.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final employees = widget.controller.employees;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Seleccionar empleados',
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  TextButton(
                    onPressed:
                        _draft.isEmpty ? null : () => setState(_draft.clear),
                    child: const Text('Limpiar'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Sin selección = todos los empleados.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: employees.length,
                itemBuilder: (_, i) {
                  final e = employees[i];
                  final checked = _draft.contains(e.uid);
                  return CheckboxListTile(
                    value: checked,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _draft.add(e.uid);
                        } else {
                          _draft.remove(e.uid);
                        }
                      });
                    },
                    secondary: ProfileAvatar(
                      name: e.name,
                      imageUrl: e.photoUrl,
                      colorValue: e.avatarColor,
                      size: 36,
                    ),
                    title: Text(
                      e.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      widget.controller.setSelectedEmployees(_draft);
                      Navigator.of(context).pop();
                    },
                    child: const Text('Aplicar'),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// =====================================================================
// LISTA DE FICHAJES
// =====================================================================

class _RecordsCard extends GetView<CompanyEntriesController> {
  const _RecordsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      final loading = controller.isLoading.value;
      final rows = controller.rows;

      if (loading) {
        return const BaseCard(
          title: 'Fichajes',
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        );
      }

      if (rows.isEmpty) {
        return BaseCard(
          title: 'Fichajes',
          children: [
            const SizedBox(height: 8),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.event_busy_outlined,
                    size: 48,
                    color: theme.colorScheme.tertiary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No hay fichajes en este rango.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      }

      return BaseCard(
        title: 'Fichajes (${rows.length})',
        children: [
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _RecordTile(row: rows[i]),
          ),
        ],
      );
    });
  }
}

class _RecordTile extends GetView<CompanyEntriesController> {
  const _RecordTile({required this.row});
  final ClockRowView row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dfDay = DateFormat('EEE d MMM', 'es_ES');

    final diff = row.diffMinutes;
    final isPositive = diff >= 0;
    final diffColor = isPositive ? Colors.green.shade700 : theme.colorScheme.error;

    return InkWell(
      onTap: () => controller.openDayDetails(context, row),
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Row(
          children: [
            ProfileAvatar(
              name: row.employeeName,
              uid: row.employeeId,
              size: 42,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.employeeName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        dfDay.format(row.day),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: theme.colorScheme.tertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        row.rangeText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _MiniBadge(
                        icon: Icons.timer_outlined,
                        text: '${row.workedHhMm} h',
                      ),
                      _MiniBadge(
                        icon: Icons.flag_outlined,
                        text: 'Prev. ${row.expectedHhMm}',
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: diffColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPositive
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              size: 13,
                              color: diffColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              row.diffSigned,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: diffColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.tertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.icon, required this.text});
  final IconData icon;
  final String text;

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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 18, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
