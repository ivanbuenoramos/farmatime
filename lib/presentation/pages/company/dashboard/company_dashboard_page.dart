import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/core/utils/date_time_utils.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/presentation/widgets/card/base_card.dart';
import 'package:farmatime/presentation/widgets/card/payment_issue_alert_card.dart';
import 'package:farmatime/presentation/widgets/card/profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'company_dashboard_controller.dart';

class CompanyDashboardPage extends GetView<CompanyDashboardController> {
  const CompanyDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'farmatime', 
          style: Get.theme.textTheme.headlineLarge?.copyWith(
            color: Colors.white, 
            fontSize: 24, 
            letterSpacing: -0.5,
            fontStyle: FontStyle.italic
          )
        ),
        centerTitle: true,
      ),
      body: Obx(() {
        if (controller.isLoading.value) return const Center(child: CircularProgressIndicator());
        final company = controller.brain.company.value;
        final billingStatus = company?.billingStatus;
        return RefreshIndicator(
          onRefresh: controller.refreshAll,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              if (company != null && billingStatus != 'active' && billingStatus != 'none') ... [
                PaymentIssueAlertCard(
                  billingStatus: billingStatus,
                ),
                const SizedBox(height: 12),
              ],
              _TodaySummaryCard(controller: controller),
              const SizedBox(height: 12),
              _EmployeesCard(controller: controller),
              const SizedBox(height: 12),
              _IncoherentCard(controller: controller),
              const SizedBox(height: 12),
              _SubscriptionCard(controller: controller),
              const SizedBox(height: 12),
              _CompanyInfoCard(controller: controller),
            ],
          ),
        );
      }),
    );
  }
}

class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard({required this.controller});
  final CompanyDashboardController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todayLabel = _capitalize(
      DateFormat("EEEE, d MMM", 'es_ES').format(DateTime.now()),
    );

    return Obx(() {
      // Lectura reactiva: depende de las listas y del tick.
      final working = controller.workingCount;
      final absent = controller.absentCount;
      final total = controller.totalEmployees;

      return BaseCard(
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 18,
                color: theme.colorScheme.tertiary,
              ),
              const SizedBox(width: 8),
              Text(
                todayLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _SummaryMetric(
                    value: '$working',
                    label: 'Trabajando',
                    color: theme.colorScheme.primary,
                  ),
                ),
                _MetricDivider(),
                Expanded(
                  child: _SummaryMetric(
                    value: '$absent',
                    label: 'Ausentes',
                    color: absent > 0
                        ? theme.colorScheme.error
                        : theme.colorScheme.secondary,
                  ),
                ),
                _MetricDivider(),
                Expanded(
                  child: _SummaryMetric(
                    value: '$total',
                    label: 'Total empleados',
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.value,
    required this.label,
    required this.color,
  });
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.tertiary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _MetricDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: VerticalDivider(
        width: 1,
        thickness: 1,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }
}

String _employeeRoleLabel(EmployeeRole role) {
  switch (role) {
    case EmployeeRole.auxiliar:
      return 'Auxiliar de farmacia';
    case EmployeeRole.farmaceutico:
      return 'Farmacéutico';
    case EmployeeRole.tecnico:
      return 'Técnico de farmacia';
    default:
      return 'Sin puesto definido';
  }
}

class _EmployeesCard extends StatelessWidget {
  const _EmployeesCard({required this.controller});
  final CompanyDashboardController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final rows = controller.allRows;

      return BaseCard(
        children: [
          _CardHeader(
            icon: Icons.groups_2_outlined,
            iconColor: Theme.of(context).colorScheme.primary,
            title: 'Empleados',
            trailing: _CountBadge(
              count: rows.length,
              color: Theme.of(context).colorScheme.tertiary,
            ),
          ),
          if (rows.isEmpty)
            const _EmptyState(
              icon: Icons.person_off_outlined,
              message: 'No hay empleados todavía.',
            )
          else
            ...List.generate(rows.length, (i) {
              return Column(
                children: [
                  _EmployeeTile(row: rows[i]),
                  if (i != rows.length - 1)
                    Divider(
                      height: 1,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                ],
              );
            }),
        ],
      );
    });
  }
}

class _EmployeeTile extends StatelessWidget {
  const _EmployeeTile({required this.row});
  final EmployeeRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = Get.find<CompanyDashboardController>();

    // Estado + color + texto de apoyo según la situación de hoy.
    late final String statusLabel;
    late final Color statusColor;
    String? subtitle;

    switch (row.status) {
      case TodayStatus.working:
        statusLabel = 'Trabajando';
        statusColor = theme.colorScheme.primary;
        if (row.lastClockIn != null) {
          subtitle = controller.relTimeFrom(row.lastClockIn!);
        }
        break;
      case TodayStatus.absent:
        statusLabel = 'Ausente';
        statusColor = theme.colorScheme.error;
        if (row.expected != null &&
            controller.now.value.isAfter(row.expected!.start)) {
          final m =
              controller.now.value.difference(row.expected!.start).inMinutes;
          subtitle = 'Sin fichar · ${m}m';
        } else {
          subtitle = 'Sin fichar';
        }
        break;
      case TodayStatus.off:
        statusLabel = 'Sin turno';
        statusColor = theme.colorScheme.tertiary;
        break;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Get.toNamed(
        Routes.companyEmployeeDetail,
        arguments: row.emp,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            ProfileAvatar(
              imageUrl: row.emp.photoUrl,
              name: row.emp.name,
              colorValue: row.emp.avatarColor,
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.emp.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle ?? _employeeRoleLabel(row.emp.role),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.tertiary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _StatusChip(
              label: statusLabel,
              color: statusColor,
              dot: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _IncoherentCard extends StatelessWidget {
  const _IncoherentCard({required this.controller});
  final CompanyDashboardController controller;

  String _fmtTime(DateTime d) => DateFormat('HH:mm').format(d);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      final alerts = controller.incoherent;
      final hasAlerts = alerts.isNotEmpty;

      return BaseCard(
        children: [
          _CardHeader(
            icon: Icons.warning_amber_rounded,
            iconColor: hasAlerts
                ? theme.colorScheme.error
                : theme.colorScheme.primary,
            title: 'Alertas de fichaje',
            trailing: hasAlerts
                ? _CountBadge(count: alerts.length, color: theme.colorScheme.error)
                : null,
          ),
          const SizedBox(height: 4),
          if (!hasAlerts)
            _EmptyState(
              icon: Icons.check_circle_outline_rounded,
              message: 'Todo en orden, sin alertas.',
            )
          else
            ...alerts.map(
              (a) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    ProfileAvatar(
                      imageUrl: a.emp.photoUrl,
                      name: a.emp.name,
                      colorValue: a.emp.avatarColor,
                      size: 40,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.emp.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Sin fichar desde las ${_fmtTime(a.date.subtract(Duration(minutes: a.deltaMinutes)))}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.tertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusChip(
                      label: '-${a.deltaMinutes}m',
                      color: theme.colorScheme.error,
                      icon: Icons.schedule_rounded,
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _SubscriptionCard extends StatelessWidget {
  final CompanyDashboardController controller;

  const _SubscriptionCard({
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateTimeUtils = DateTimeUtils();

    final company = controller.brain.company.value;

    if (company == null) {
      return const SizedBox.shrink();
    }

    final hasSubscription = company.hasActiveSubscription;

    final totalSeats = company.contractedSeats ?? 1;
    final usedSeats = controller.brain.companyEmployees.length;

    final seatsRatio = totalSeats == 0 ? 0.0 : (usedSeats / totalSeats).clamp(0.0, 1.0);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Get.toNamed(Routes.companySubscription),
      child: BaseCard(
        children: [
          _CardHeader(
            icon: Icons.workspace_premium_outlined,
            iconColor: theme.colorScheme.primary,
            title: 'Suscripción',
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.tertiary,
            ),
          ),
          const SizedBox(height: 4),

          // Plan + estado
          Row(
            children: [
              _StatusChip(
                label: hasSubscription ? 'Plan activo' : 'Plan gratuito',
                color: hasSubscription
                    ? const Color(0xff16A34A)
                    : theme.colorScheme.tertiary,
                icon: hasSubscription
                    ? Icons.verified_rounded
                    : Icons.lock_open_rounded,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Plazas (seats) con barra de progreso
          Row(
            children: [
              Icon(Icons.group_outlined,
                  size: 18, color: theme.colorScheme.secondary),
              const SizedBox(width: 6),
              Text(
                'Plazas usadas',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
              const Spacer(),
              Text(
                '$usedSeats / $totalSeats',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: seatsRatio,
              minHeight: 8,
              backgroundColor: theme.colorScheme.outline,
              valueColor: AlwaysStoppedAnimation(
                theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Detalle inferior: renovación o plan gratuito
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  hasSubscription
                      ? Icons.event_available_rounded
                      : Icons.info_outline_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasSubscription
                        ? 'Próxima renovación: ${company.currentPeriodEnd != null ? dateTimeUtils.formatDateToString(company.currentPeriodEnd!) : '—'}'
                        : '1 empleado incluido. Mejora tu plan para añadir más.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanyInfoCard extends StatelessWidget {
  const _CompanyInfoCard({required this.controller});
  final CompanyDashboardController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final company = controller.brain.company.value;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: controller.redirectToComapnyProfile,
      child: BaseCard(
        children: [
          _CardHeader(
            icon: Icons.storefront_outlined,
            iconColor: theme.colorScheme.primary,
            title: 'Datos de la empresa',
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.tertiary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              ProfileAvatar(
                name: company?.legalName ?? '—',
                imageUrl: company?.logoUrl,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      company?.legalName ?? '—',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.secondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      company?.email ?? '—',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.tertiary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.badge_outlined,
            label: 'CIF',
            value: company?.vatNumber ?? '—',
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.location_on_outlined,
            label: 'Dirección',
            value: company?.address?.address ?? '—',
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.location_city_outlined,
            label: 'Ciudad',
            value: company?.address?.city ?? '—',
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.tertiary),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.tertiary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// WIDGETS COMPARTIDOS
// =====================================================================

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.icon,
    required this.title,
    this.iconColor,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Color? iconColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = iconColor ?? theme.colorScheme.primary;
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.color});
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    this.icon,
    this.dot = false,
  });

  final String label;
  final Color color;
  final IconData? icon;

  /// Estilo "punto + texto" sobre fondo gris suave (como la referencia).
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor =
        dot ? theme.colorScheme.outline.withOpacity(0.4) : color.withOpacity(0.12);
    final textColor = dot ? theme.colorScheme.secondary : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ] else if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.tertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.tertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
