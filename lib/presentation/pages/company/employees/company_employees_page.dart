import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/presentation/pages/company/employees/widgets/info_locked_dialog.dart';
import 'package:farmatime/presentation/widgets/card/base_card.dart';
import 'package:farmatime/presentation/widgets/card/payment_issue_alert_card.dart';
import 'package:farmatime/presentation/widgets/card/profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:farmatime/presentation/pages/company/employees/company_employees_controller.dart';

class CompanyEmployeesPage extends GetView<CompanyEmployeesController> {
  const CompanyEmployeesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de empleados'),
        titleSpacing: 16,
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'employees_fab',
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        onPressed: controller.onAddEmployeePressed,
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        final employees = controller.employees;
        final seats = controller.effectiveSeats;
        final totalCards = (seats > employees.length) ? seats : employees.length;
        final billingStatus = controller.brain.company.value?.billingStatus;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
          child: Column(
            children: [
              if (billingStatus != null &&
                  billingStatus != 'active' &&
                  billingStatus != 'none') ...[
                PaymentIssueAlertCard(billingStatus: billingStatus),
                const SizedBox(height: 12),
              ],
              _TimeOffAccessCard(controller: controller),
              const SizedBox(height: 12),
              _EmployeesCard(
                controller: controller,
                employees: employees,
                seats: seats,
                totalCards: totalCards,
              ),
            ],
          ),
        );
      }),
    );
  }
}

// =====================================================================
// TARJETA: EMPLEADOS
// =====================================================================

class _EmployeesCard extends StatelessWidget {
  const _EmployeesCard({
    required this.controller,
    required this.employees,
    required this.seats,
    required this.totalCards,
  });

  final CompanyEmployeesController controller;
  final List<EmployeeModel> employees;
  final int seats;
  final int totalCards;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BaseCard(
      children: [
        _CardHeader(
          icon: Icons.groups_2_outlined,
          title: 'Empleados',
          trailing: _CountBadge(
            label: '${employees.length}/$seats',
            color: theme.colorScheme.tertiary,
          ),
        ),

        if (controller.isLoading.value) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
        ],

        ListView.separated(
          shrinkWrap: true,
          itemCount: totalCards,
          physics: const NeverScrollableScrollPhysics(),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index < employees.length) {
              final employee = employees[index];
              final allowedByBilling = controller.canAccessEmployee(employee);
              final isActive =
                  employee.accountStatus == EmployeeAccountStatus.active ||
                      employee.accountStatus == EmployeeAccountStatus.pending;
              final canOpen = isActive && allowedByBilling;

              return _EmployeeTile(
                employee: employee,
                allowedByBilling: allowedByBilling,
                canOpen: canOpen,
                onTap: () {
                  if (canOpen) {
                    controller.reditectToEmployeeDetail(employee);
                  } else {
                    showEmployeeInfoLockedDialog();
                  }
                },
              );
            }

            return DottedSlotCard(
              onTap: controller.onAddEmployeePressed,
              enabled: controller.subscriptionIsOk,
            );
          },
        ),
      ],
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  const _EmployeeTile({
    required this.employee,
    required this.allowedByBilling,
    required this.canOpen,
    required this.onTap,
  });

  final EmployeeModel employee;
  final bool allowedByBilling;
  final bool canOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _statusInfo(employee.accountStatus, theme);

    return Opacity(
      opacity: canOpen ? 1.0 : 0.6,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surface,
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Row(
            children: [
              ProfileAvatar(
                imageUrl: employee.photoUrl,
                name: employee.name,
                colorValue: employee.avatarColor,
                size: 46,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _StatusChip(
                          label: status.label,
                          color: status.color,
                          dot: true,
                        ),
                        if (employee.workdayType != null)
                          _StatusChip(
                            label: employee.workdayType == WorkdayType.completa
                                ? 'Jornada completa'
                                : 'Parcial',
                            color: theme.colorScheme.primary,
                            icon: Icons.schedule_rounded,
                          ),
                        if (!allowedByBilling)
                          _StatusChip(
                            label: 'Bloqueado',
                            color: theme.colorScheme.tertiary,
                            icon: Icons.lock_outline_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.tertiary,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }

  ({String label, Color color}) _statusInfo(
      EmployeeAccountStatus? status, ThemeData theme) {
    switch (status) {
      case EmployeeAccountStatus.active:
        return (label: 'Activo', color: const Color(0xff16A34A));
      case EmployeeAccountStatus.pending:
        return (label: 'Pendiente', color: const Color(0xffF59E0B));
      case EmployeeAccountStatus.inactive:
        return (label: 'Inactivo', color: theme.colorScheme.tertiary);
      case EmployeeAccountStatus.disabled:
        return (label: 'Deshabilitado', color: theme.colorScheme.error);
      default:
        return (label: 'Desconocido', color: theme.colorScheme.tertiary);
    }
  }
}

// =====================================================================
// SOLICITUDES DE AUSENCIA
// =====================================================================

class _TimeOffAccessCard extends StatelessWidget {
  const _TimeOffAccessCard({required this.controller});
  final CompanyEmployeesController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      final pending = controller.pendingTimeOff.value;
      return InkWell(
        onTap: controller.redirectToTimeOff,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: theme.colorScheme.surface,
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withOpacity(0.1),
                ),
                child: Icon(Icons.event_note_rounded,
                    color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Solicitudes de ausencia',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pending > 0
                          ? '$pending pendiente${pending == 1 ? '' : 's'} de revisar'
                          : 'Vacaciones y asuntos propios',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.tertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (pending > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$pending',
                    style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded,
                  color: theme.colorScheme.tertiary, size: 26),
            ],
          ),
        ),
      );
    });
  }
}

// =====================================================================
// SLOT VACÍO (HUECO CONTRATADO LIBRE)
// =====================================================================

class DottedSlotCard extends StatelessWidget {
  final VoidCallback? onTap;
  final bool enabled;

  const DottedSlotCard({
    this.onTap,
    this.enabled = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: enabled ? 1.0 : 0.6,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.primary.withOpacity(0.05),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.35),
            ),
          ),
          child: Row(
            children: [
              Container(
                height: 46,
                width: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withOpacity(0.1),
                ),
                child: Icon(
                  Icons.person_add_alt_1,
                  size: 22,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Añadir empleado',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      enabled ? 'Hueco libre' : 'Bloqueado por pago',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.tertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// WIDGETS COMPARTIDOS
// =====================================================================

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.icon, required this.title, this.trailing});
  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
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
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.w700,
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
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor =
        dot ? theme.colorScheme.outline.withOpacity(0.4) : color.withOpacity(0.12);
    final textColor = dot ? theme.colorScheme.secondary : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
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
