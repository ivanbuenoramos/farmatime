import 'package:farmatime/core/utils/leave_dates_utils.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/data/models/schedule/day_entry.dart';
import 'package:farmatime/data/models/schedule/time_off_model.dart';
import 'package:farmatime/presentation/widgets/card/profile_avatar.dart';
import 'package:farmatime/presentation/widgets/modals/employee_day_detail_modal.dart';
import 'package:farmatime/presentation/widgets/schedule/schedule_calendar.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

import 'package:farmatime/presentation/widgets/card/base_card.dart';
import 'package:farmatime/presentation/pages/company/employee_detail/company_employee_detail_controller.dart';

class EmployeeDetailPage extends GetView<EmployeeDetailController> {
  const EmployeeDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil de empleado'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                onTap: () =>
                    controller.reditectToUpsertEmployee(controller.employee.value),
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, color: theme.colorScheme.secondary),
                    const SizedBox(width: 8),
                    Text('Editar empleado',
                        style: TextStyle(color: theme.colorScheme.secondary)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                onTap: () =>
                    controller.redirectToDeleteEmployee(controller.employee.value!),
                child: Row(
                  children: [
                    Icon(Icons.delete_rounded, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Text('Eliminar empleado',
                        style: TextStyle(color: theme.colorScheme.error)),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
      body: Obx(() {
        final employee = controller.employee.value;
        if (employee == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProfileHeader(employee: employee),
              const SizedBox(height: 12),
              _LeaveBalancesCard(theme: theme),
              const SizedBox(height: 12),
              _TimeOffRequestsCard(),
              const SizedBox(height: 12),
              _ScheduleCard(theme: theme),
              const SizedBox(height: 12),
              _ClockInsCard(employee: employee),
            ],
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Cabecera de perfil
// ─────────────────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.employee});
  final EmployeeModel employee;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _statusInfo(employee.accountStatus, theme);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            Color.lerp(theme.colorScheme.primary, Colors.black, 0.18)!,
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
                ),
                child: ProfileAvatar(
                  imageUrl: employee.photoUrl,
                  name: employee.name,
                  colorValue: employee.avatarColor,
                  size: 64,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.name,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _roleLabel(employee),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeaderChip(
                icon: Icons.circle,
                iconSize: 10,
                label: status.label,
                color: status.color,
              ),
              if (employee.workdayType != null)
                _HeaderChip(
                  icon: Icons.schedule_rounded,
                  label: employee.workdayType == WorkdayType.completa
                      ? 'Jornada completa'
                      : 'Jornada parcial',
                ),
              _HeaderChip(
                icon: Icons.event_rounded,
                label: 'Alta ${DateFormat('d MMM y', 'es_ES').format(employee.hireDate)}',
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Contacto rápido
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.mail_outline_rounded,
                    color: Colors.white.withValues(alpha: 0.9), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    employee.email,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _roleLabel(EmployeeModel e) {
    switch (e.role) {
      case EmployeeRole.auxiliar:
        return 'Auxiliar de farmacia';
      case EmployeeRole.farmaceutico:
        return 'Farmacéutico';
      case EmployeeRole.tecnico:
        return 'Técnico de farmacia';
      case EmployeeRole.otro:
        return e.roleOther?.trim().isNotEmpty == true
            ? e.roleOther!.trim()
            : 'Otro puesto';
    }
  }

  ({String label, Color color}) _statusInfo(
      EmployeeAccountStatus? status, ThemeData theme) {
    switch (status) {
      case EmployeeAccountStatus.active:
        return (label: 'Activo', color: const Color(0xff35E08B));
      case EmployeeAccountStatus.pending:
        return (label: 'Pendiente', color: const Color(0xffFFC65C));
      case EmployeeAccountStatus.inactive:
        return (label: 'Inactivo', color: Colors.white70);
      case EmployeeAccountStatus.disabled:
        return (label: 'Deshabilitado', color: const Color(0xffFF8A8A));
      default:
        return (label: 'Desconocido', color: Colors.white70);
    }
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.icon,
    required this.label,
    this.color,
    this.iconSize = 14,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color ?? Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Saldos de vacaciones / asuntos propios
// ─────────────────────────────────────────────────────────────
class _LeaveBalancesCard extends GetView<EmployeeDetailController> {
  const _LeaveBalancesCard({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      title: 'Días disponibles',
      children: [
        const SizedBox(height: 4),
        Obx(() {
          final b = controller.balances.value;
          return Row(
            children: [
              Expanded(
                child: _BalanceTile(
                  icon: Icons.beach_access_rounded,
                  label: 'Vacaciones',
                  value: b?.vacationAvailable,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BalanceTile(
                  icon: Icons.event_available_rounded,
                  label: 'Asuntos propios',
                  value: b?.personalAvailable,
                  color: const Color(0xff8E24AA),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final double? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value == null ? '—' : _fmt(value!),
                style: theme.textTheme.headlineLarge?.copyWith(color: color),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'días',
                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1).replaceAll('.', ',');
  }
}

// ─────────────────────────────────────────────────────────────
// Calendario (solo lectura) con acceso a edición
// ─────────────────────────────────────────────────────────────
class _ScheduleCard extends GetView<EmployeeDetailController> {
  const _ScheduleCard({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      title: 'Calendario',
      actions: [
        TextButton.icon(
          onPressed: controller.redirectToEmployeeSchedule,
          icon: Icon(Icons.edit_calendar_rounded,
              size: 18, color: theme.colorScheme.primary),
          label: Text('Editar',
              style: TextStyle(color: theme.colorScheme.primary, fontSize: 14)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
      children: [
        Obx(() {
          if (controller.isLoadingSchedule.value &&
              controller.scheduleOverrides.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          return EmployeeScheduleCalendar(
            firstDay: DateTime.utc(DateTime.now().year - 1, 1, 1),
            lastDay: DateTime.utc(DateTime.now().year + 2, 12, 31),
            focusedDay: controller.calendarFocusedDay.value,
            selectedDay: null,
            rangeStart: null,
            rangeEnd: null,
            overridesByDay: Map<DateTime, dynamic>.from(controller.scheduleOverrides)
                .cast<DateTime, DayEntry>(),
            rules: controller.scheduleRules,
            onPageChanged: controller.onCalendarPageChanged,
            onDayTap: (day) => showEmployeeDayDetailModal(
              context: context,
              day: day,
              expected: controller.computedEntryFor(day),
              records: controller.clockRecordsForDay(day),
            ),
            locale: 'es_ES',
            showTimes: true,
            compact: true,
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Fichajes del mes
// ─────────────────────────────────────────────────────────────
class _ClockInsCard extends GetView<EmployeeDetailController> {
  const _ClockInsCard({required this.employee});
  final EmployeeModel employee;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BaseCard(
      title: 'Fichajes',
      actions: [
        Obx(() {
          final monthStr =
              DateFormat.MMMM('es_ES').format(controller.selectedMonth.value);
          return Row(
            children: [
              _MonthArrow(
                icon: Icons.chevron_left_rounded,
                onTap: controller.prevMonth,
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 86,
                child: Text(
                  monthStr[0].toUpperCase() + monthStr.substring(1),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _MonthArrow(
                icon: Icons.chevron_right_rounded,
                onTap: controller.nextMonth,
              ),
            ],
          );
        }),
      ],
      children: [
        Obx(() {
          final month = controller.selectedMonth.value;
          final filtered = controller.groupedClockIns.entries
              .where((e) => e.key.year == month.year && e.key.month == month.month)
              .toList()
            ..sort((a, b) => b.key.compareTo(a.key));

          if (filtered.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.schedule_rounded,
                        color: theme.colorScheme.tertiary, size: 28),
                    const SizedBox(height: 8),
                    Text('Sin fichajes este mes',
                        style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              for (final dayGroup in filtered)
                _ClockInRow(dayGroup: dayGroup, theme: theme),
            ],
          );
        }),
      ],
    );
  }
}

class _ClockInRow extends StatelessWidget {
  const _ClockInRow({required this.dayGroup, required this.theme});
  final MapEntry<DateTime, List<dynamic>> dayGroup;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final items = dayGroup.value.sorted((a, b) => a.time.compareTo(b.time));

    Duration worked = Duration.zero;
    for (var i = 0; i < items.length; i += 2) {
      if (i + 1 < items.length && items[i].type == ClockInOutType.entry) {
        final out = items[i + 1];
        if (out.type == ClockInOutType.exit) {
          worked += out.time.difference(items[i].time);
        }
      }
    }

    final workedText =
        '${worked.inHours}h ${worked.inMinutes.remainder(60).toString().padLeft(2, '0')}m';
    final diff = worked - const Duration(hours: 8);
    final isNeg = diff.isNegative;
    final diffText = '${isNeg ? '−' : '+'}${diff.inMinutes.abs()}m';
    final diffColor = isNeg ? theme.colorScheme.error : const Color(0xff16A34A);

    final dayLabel = DateFormat('EEE d', 'es_ES').format(dayGroup.key);
    final pairs = items.length ~/ 2;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Día
          SizedBox(
            width: 54,
            child: Text(
              dayLabel[0].toUpperCase() + dayLabel.substring(1),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.secondary,
              ),
            ),
          ),
          // Fichajes count
          _MiniInfo(
            icon: Icons.login_rounded,
            text: '$pairs',
            theme: theme,
          ),
          const SizedBox(width: 14),
          // Trabajado
          Expanded(
            child: Row(
              children: [
                Icon(Icons.timelapse_rounded,
                    size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  workedText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Diferencia vs 8h
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: diffColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              diffText,
              style: theme.textTheme.labelSmall?.copyWith(
                color: diffColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({required this.icon, required this.text, required this.theme});
  final IconData icon;
  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.tertiary),
        const SizedBox(width: 4),
        Text(text, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _MonthArrow extends StatelessWidget {
  const _MonthArrow({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: theme.colorScheme.primary, size: 20),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Tarjeta de solicitudes de ausencia del empleado
// ─────────────────────────────────────────────────────────────
class _TimeOffRequestsCard extends GetView<EmployeeDetailController> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      final requests = controller.timeOffRequests;
      final pending = controller.pendingTimeOffCount;
      return BaseCard(
        title: 'Solicitudes',
        actions: [
          if (pending > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$pending pendiente${pending == 1 ? '' : 's'}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
        ],
        children: [
          if (requests.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Sin solicitudes de vacaciones o asuntos propios.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          else
            ...requests.map((r) => _TimeOffRow(
                  request: r,
                  onManage: () => controller.manageTimeOff(context, r),
                )),
        ],
      );
    });
  }
}

class _TimeOffRow extends StatelessWidget {
  final TimeOffModel request;
  final VoidCallback onManage;
  const _TimeOffRow({required this.request, required this.onManage});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actionable = request.awaitingCompany;
    final Color statusColor = switch (request.status) {
      TimeOffStatus.requested => theme.colorScheme.secondary,
      TimeOffStatus.proposed => theme.colorScheme.primary,
      TimeOffStatus.approved => const Color(0xff35B58D),
      TimeOffStatus.rejected => theme.colorScheme.error,
      TimeOffStatus.cancelled => theme.colorScheme.outline,
    };

    return InkWell(
      onTap: onManage,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: actionable
                ? theme.colorScheme.primary.withValues(alpha: 0.6)
                : theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              request.type == TimeOffType.vacation
                  ? Icons.beach_access_rounded
                  : Icons.event_available_rounded,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(request.type.label,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(formatDatesSummary(request.effectiveDates),
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                request.status.label,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: statusColor, fontWeight: FontWeight.w600),
              ),
            ),
            if (actionable) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outline),
            ],
          ],
        ),
      ),
    );
  }
}
