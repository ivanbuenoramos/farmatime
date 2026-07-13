// lib/presentation/pages/employee/request_leave/request_leave_page.dart
import 'package:farmatime/core/utils/leave_dates_utils.dart';
import 'package:farmatime/data/models/schedule/time_off_model.dart';
import 'package:farmatime/presentation/widgets/card/base_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'request_leave_controller.dart';

/// Color por tipo de permiso: vacaciones en rojo, asuntos propios en morado.
const Color kVacationColor = Color(0xffE53935);
const Color kPersonalColor = Color(0xff8E24AA);

Color colorForType(TimeOffType type) =>
    type == TimeOffType.vacation ? kVacationColor : kPersonalColor;

class RequestLeavePage extends GetView<RequestLeaveController> {
  const RequestLeavePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitar vacaciones y permisos'),
        titleSpacing: 0,
      ),
      bottomNavigationBar: Obx(() {
        final canSend = controller.isValid && !controller.submitting.value;
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: theme.colorScheme.outline)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SafeArea(
            top: false,
            child: FilledButton.icon(
              onPressed: canSend ? controller.submit : null,
              icon: controller.submitting.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                controller.submitting.value ? 'Enviando…' : 'Enviar solicitud',
              ),
            ),
          ),
        );
      }),
      body: Obx(() {
        final type = controller.leaveType.value;
        final s = controller.startDate.value;
        final e = controller.endDate.value;
        final total = controller.totalDays;
        final mode = controller.selectionMode.value;
        final selectedDays = controller.selectedDays.toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Tipo de solicitud ──────────────────────────────
              BaseCard(
                title: 'Tipo de solicitud',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _TypeOption(
                          icon: Icons.beach_access_rounded,
                          label: 'Vacaciones',
                          color: kVacationColor,
                          selected: type == LeaveType.vacaciones,
                          onTap: () =>
                              controller.setLeaveType(LeaveType.vacaciones),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TypeOption(
                          icon: Icons.event_note_rounded,
                          label: 'Asuntos propios',
                          color: kPersonalColor,
                          selected: type == LeaveType.personales,
                          onTap: () =>
                              controller.setLeaveType(LeaveType.personales),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Saldos disponibles ─────────────────────────────
              _BalancesCard(controller: controller),
              const SizedBox(height: 12),

              // ── Modo de selección ──────────────────────────────
              BaseCard(
                title: 'Modo de selección',
                children: [
                  _SegmentedToggle(
                    leftLabel: 'Rango de fechas',
                    leftIcon: Icons.date_range_rounded,
                    rightLabel: 'Días sueltos',
                    rightIcon: Icons.event_available_rounded,
                    leftSelected: mode == LeaveSelectionMode.range,
                    onLeft: () =>
                        controller.setSelectionMode(LeaveSelectionMode.range),
                    onRight: () => controller
                        .setSelectionMode(LeaveSelectionMode.multiple),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Selección de fechas según modo ─────────────────
              if (mode == LeaveSelectionMode.range)
                BaseCard(
                  title: 'Rango de fechas',
                  children: [
                    _RangePickerTile(
                      start: s,
                      end: e,
                      onTap: () => controller.pickRange(context),
                    ),
                    const SizedBox(height: 10),
                    _Hint(
                      'Para un único día, elige la misma fecha de inicio y fin.',
                    ),
                  ],
                )
              else
                BaseCard(
                  title: 'Días sueltos',
                  children: [
                    if (selectedDays.isEmpty)
                      _Hint('Aún no has añadido ningún día.')
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final d in selectedDays)
                            _DayChip(
                              date: d,
                              onDeleted: () => controller.removeDay(d),
                            ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => controller.pickSingleDay(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Añadir día'),
                    ),
                    const SizedBox(height: 8),
                    _Hint(
                      'Selecciona uno o varios días no consecutivos. Pulsa la “x” para quitar uno.',
                    ),
                  ],
                ),
              const SizedBox(height: 12),

              // ── Comentario opcional ────────────────────────────
              BaseCard(
                title: 'Comentario (opcional)',
                children: [
                  TextField(
                    controller: controller.noteCtrl,
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: 'Añade información útil para tu responsable…',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Resumen ────────────────────────────────────────
              _SummaryCard(
                typeLabel: type == LeaveType.vacaciones
                    ? 'Vacaciones'
                    : 'Asuntos propios',
                start: s,
                end: e,
                totalDays: total,
                mode: mode,
                multipleDays: selectedDays,
              ),
              const SizedBox(height: 12),

              // ── Mis solicitudes ────────────────────────────────
              _MyRequestsCard(controller: controller),

              const SizedBox(height: 20),
            ],
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Selector de tipo (tarjeta seleccionable)
// ─────────────────────────────────────────────────────────────
class _TypeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _TypeOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.08)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : theme.colorScheme.outline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: selected ? color : theme.colorScheme.tertiary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: selected ? color : theme.colorScheme.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Saldos: disponibles / asignados / gastados + cadencia
// ─────────────────────────────────────────────────────────────
class _BalancesCard extends StatelessWidget {
  final RequestLeaveController controller;
  const _BalancesCard({required this.controller});

  static String _fmtDays(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Lectura reactiva: depende de las solicitudes para recalcular.
      controller.myRequests.length;
      final b = controller.balances;

      return BaseCard(
        title: 'Tus saldos',
        children: [
          if (b == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Column(
              children: [
                _BalancePanel(
                  icon: Icons.beach_access_rounded,
                  color: kVacationColor,
                  title: 'Vacaciones',
                  available: _fmtDays(b.vacationAvailable),
                  upcoming: '${controller.vacationUpcoming}',
                  spent: '${controller.vacationSpent}',
                  cadence: controller.vacationCadenceLabel,
                ),
                const SizedBox(height: 12),
                _BalancePanel(
                  icon: Icons.event_note_rounded,
                  color: kPersonalColor,
                  title: 'Asuntos propios',
                  available: _fmtDays(b.personalAvailable),
                  upcoming: '${controller.personalUpcoming}',
                  spent: '${controller.personalSpent}',
                  cadence: controller.personalCadenceLabel,
                ),
              ],
            ),
        ],
      );
    });
  }
}

class _BalancePanel extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String available;
  final String upcoming;
  final String spent;
  final String cadence;

  const _BalancePanel({
    required this.icon,
    required this.color,
    required this.title,
    required this.available,
    required this.upcoming,
    required this.spent,
    required this.cadence,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera: tipo + disponibles destacados
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Disponibles',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.tertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    available,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
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
          const SizedBox(height: 12),
          // Asignados (futuros) / Gastados (pasados)
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Asignados',
                  value: upcoming,
                  color: theme.colorScheme.secondary,
                ),
              ),
              Container(
                width: 1,
                height: 30,
                color: theme.colorScheme.outline,
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Gastados',
                  value: spent,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Cadencia de devengo
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.trending_up_rounded,
                  size: 15, color: theme.colorScheme.tertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  cadence,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.tertiary,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Toggle segmentado (Rango / Días sueltos)
// ─────────────────────────────────────────────────────────────
class _SegmentedToggle extends StatelessWidget {
  final String leftLabel;
  final IconData leftIcon;
  final String rightLabel;
  final IconData rightIcon;
  final bool leftSelected;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  const _SegmentedToggle({
    required this.leftLabel,
    required this.leftIcon,
    required this.rightLabel,
    required this.rightIcon,
    required this.leftSelected,
    required this.onLeft,
    required this.onRight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.outline.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              icon: leftIcon,
              label: leftLabel,
              selected: leftSelected,
              onTap: onLeft,
            ),
          ),
          Expanded(
            child: _SegmentButton(
              icon: rightIcon,
              label: rightLabel,
              selected: !leftSelected,
              onTap: onRight,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.tertiary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.tertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Tile selector de rango
// ─────────────────────────────────────────────────────────────
class _RangePickerTile extends StatelessWidget {
  final DateTime? start;
  final DateTime? end;
  final VoidCallback onTap;

  const _RangePickerTile({
    required this.start,
    required this.end,
    required this.onTap,
  });

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasRange = start != null && end != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.date_range_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasRange
                    ? '${_fmt(start!)}  —  ${_fmt(end!)}'
                    : 'Selecciona un rango de fechas',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: hasRange
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.tertiary,
                  fontWeight: hasRange ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: theme.colorScheme.tertiary),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Resumen
// ─────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final String typeLabel;
  final DateTime? start;
  final DateTime? end;
  final int totalDays;
  final LeaveSelectionMode mode;
  final List<DateTime> multipleDays;

  const _SummaryCard({
    required this.typeLabel,
    required this.start,
    required this.end,
    required this.totalDays,
    required this.mode,
    required this.multipleDays,
  });

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BaseCard(
      title: 'Resumen',
      children: [
        _Row('Tipo', typeLabel),
        if (mode == LeaveSelectionMode.range) ...[
          _Row('Inicio', start != null ? _fmt(start!) : '—'),
          _Row('Fin', end != null ? _fmt(end!) : '—'),
        ] else ...[
          _Row(
            'Días seleccionados',
            multipleDays.isEmpty ? '—' : '${multipleDays.length}',
          ),
          if (multipleDays.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: multipleDays
                    .map(
                      (d) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _fmt(d),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.event_available_rounded,
                  size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Total de días',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                totalDays > 0 ? '$totalDays' : '—',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  final DateTime date;
  final VoidCallback onDeleted;
  const _DayChip({required this.date, required this.onDeleted});

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _fmt(date),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onDeleted,
            borderRadius: BorderRadius.circular(20),
            child: Icon(
              Icons.close_rounded,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.tertiary,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded,
            size: 15, color: theme.colorScheme.tertiary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.tertiary,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Mis solicitudes (estado + responder a contrapropuestas + cancelar)
// ─────────────────────────────────────────────────────────────
class _MyRequestsCard extends StatelessWidget {
  final RequestLeaveController controller;
  const _MyRequestsCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      final requests = controller.myRequests;
      return BaseCard(
        title: 'Mis solicitudes',
        children: [
          if (controller.loadingRequests.value)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (requests.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Icon(Icons.inbox_rounded,
                      size: 36, color: theme.colorScheme.tertiary),
                  const SizedBox(height: 8),
                  Text(
                    'Todavía no has enviado ninguna solicitud.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                ],
              ),
            )
          else
            ...requests.map(
              (r) => _RequestTile(controller: controller, request: r),
            ),
        ],
      );
    });
  }
}

class _RequestTile extends StatelessWidget {
  final RequestLeaveController controller;
  final TimeOffModel request;
  const _RequestTile({required this.controller, required this.request});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isProposal = request.awaitingEmployee;
    final canCancel = request.isPending;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                request.type == TimeOffType.vacation
                    ? Icons.beach_access_rounded
                    : Icons.event_note_rounded,
                size: 18,
                color: colorForType(request.type),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  request.type.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _StatusChip(status: request.status),
            ],
          ),
          const SizedBox(height: 8),
          _DetailLine(
            icon: Icons.calendar_today_rounded,
            text: 'Solicitado: ${formatDatesSummary(request.dates)}',
            color: theme.colorScheme.secondary,
          ),
          if (request.proposedDates.isNotEmpty) ...[
            const SizedBox(height: 4),
            _DetailLine(
              icon: Icons.swap_horiz_rounded,
              text:
                  'Propuesta de la empresa: ${formatDatesSummary(request.proposedDates)}',
              color: theme.colorScheme.primary,
            ),
          ],
          if (request.companyNote != null &&
              request.companyNote!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '“${request.companyNote!.trim()}”',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          if (isProposal) ...[
            const SizedBox(height: 12),
            Obx(() {
              final busy = controller.decidingId.value == request.id;
              return Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          busy ? null : () => controller.rejectProposal(request),
                      child: const Text('Rechazar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          busy ? null : () => controller.acceptProposal(request),
                      child: busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Aceptar'),
                    ),
                  ),
                ],
              );
            }),
          ] else if (canCancel) ...[
            const SizedBox(height: 10),
            Obx(() {
              final busy = controller.decidingId.value == request.id;
              return Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed:
                      busy ? null : () => controller.cancelRequest(request),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  icon: busy
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.error,
                          ),
                        )
                      : Icon(Icons.cancel_outlined,
                          size: 16, color: theme.colorScheme.error),
                  label: const Text('Cancelar solicitud'),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _DetailLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final TimeOffStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color color = switch (status) {
      TimeOffStatus.requested => theme.colorScheme.tertiary,
      TimeOffStatus.proposed => theme.colorScheme.primary,
      TimeOffStatus.approved => const Color(0xff35B58D),
      TimeOffStatus.rejected => theme.colorScheme.error,
      TimeOffStatus.cancelled => theme.colorScheme.tertiary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: theme.textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
