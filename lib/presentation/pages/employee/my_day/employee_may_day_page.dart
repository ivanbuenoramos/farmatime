import 'package:farmatime/presentation/widgets/buttons/block_button.dart';
import 'package:farmatime/presentation/widgets/card/base_card.dart';
import 'package:farmatime/presentation/widgets/card/profile_avatar.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:farmatime/presentation/pages/employee/my_day/employee_may_day_controller.dart';

class EmployeeMyDayPage extends GetView<EmployeeMyDayController> {
  const EmployeeMyDayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'farmatime',
          style: theme.textTheme.headlineLarge?.copyWith(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 24,
            fontStyle: FontStyle.italic,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              children: [
                _GreetingHeader(controller: controller),
                const SizedBox(height: 18),
                _StatusHeroCard(controller: controller),
                const SizedBox(height: 12),
                _ScheduleCard(controller: controller),
                const SizedBox(height: 12),
                _TodayClockingsCard(controller: controller),
                const SizedBox(height: 8),
              ],
            ),
          ),
          _ClockActionBar(controller: controller),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Saludo + avatar + fecha
// ─────────────────────────────────────────────────────────────
class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.controller});
  final EmployeeMyDayController controller;

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      final emp = controller.brain.employee.value;
      final name = emp?.name ?? '';
      final firstName = name.trim().isEmpty ? '' : name.trim().split(' ').first;
      final dateLabel = _capitalize(
        DateFormat('EEEE, d MMM', 'es_ES').format(DateTime.now()),
      );

      return Row(
        children: [
          ProfileAvatar(
            name: name.isEmpty ? '?' : name,
            imageUrl: emp?.photoUrl,
            uid: emp?.uid,
            size: 52,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  firstName.isEmpty ? '¡Hola!' : '¡Hola, $firstName!',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  dateLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────
// Tarjeta principal de estado (cronómetro en vivo / listo) + total hoy
// ─────────────────────────────────────────────────────────────
class _StatusHeroCard extends StatelessWidget {
  const _StatusHeroCard({required this.controller});
  final EmployeeMyDayController controller;

  String _hms(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      final entry = controller.currentEntry.value;
      final active = entry != null;
      final accent = active
          ? theme.colorScheme.primary
          : theme.colorScheme.tertiary;

      // Base blanca sólida detrás para que el gradiente con opacidad se
      // pinte sobre blanco y no sobre el gris del fondo del scaffold.
      return Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: active
                  ? [
                      theme.colorScheme.primary.withValues(alpha: 0.12),
                      theme.colorScheme.primary.withValues(alpha: 0.04),
                    ]
                  : [
                      theme.colorScheme.outline.withValues(alpha: 0.30),
                      theme.colorScheme.outline.withValues(alpha: 0.12),
                    ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Estado actual
              Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    active ? 'Trabajando ahora' : 'Sin entrada activa',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Cronómetro / mensaje
              if (active)
                Obx(() {
                  final duration = controller.currentDuration.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _hms(duration),
                        style: theme.textTheme.headlineLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Desde tu última entrada (${DateFormat.Hm().format(entry.clockIn)})',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                    ],
                  );
                })
              else
                Text(
                  'No tienes ninguna entrada activa. Pulsa “Fichar entrada” para empezar tu jornada.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
                ),

              const SizedBox(height: 16),
              Divider(height: 1, color: accent.withValues(alpha: 0.20)),
              const SizedBox(height: 12),

              // Total hoy + nº de turnos
              Row(
                children: [
                  Expanded(
                    child: Obx(() {
                      // Dependencia reactiva del contador en vivo.
                      controller.currentDuration.value;
                      return _HeroStat(
                        icon: Icons.access_time_filled_rounded,
                        label: 'Trabajado hoy',
                        value: controller.formatDurationHm(
                          controller.totalWorkedTodayLive,
                        ),
                        color: theme.colorScheme.secondary,
                      );
                    }),
                  ),
                  Container(
                    width: 1,
                    height: 34,
                    color: theme.colorScheme.outline,
                  ),
                  Expanded(
                    child: Obx(
                      () => _HeroStat(
                        icon: Icons.repeat_rounded,
                        label: 'Turnos hoy',
                        value: '${controller.todayShiftCount}',
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.tertiary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.tertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Horario de hoy (con contador / vas tarde)
// ─────────────────────────────────────────────────────────────
class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.controller});
  final EmployeeMyDayController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BaseCard(
      title: 'Horario de hoy',
      children: [
        const SizedBox(height: 4),
        Obx(() {
          final expected = controller.todayExpected.value;

          if (expected == null) {
            return Row(
              children: [
                Icon(
                  Icons.weekend_rounded,
                  size: 20,
                  color: theme.colorScheme.tertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No tienes turno asignado para hoy.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                ),
              ],
            );
          }

          final startStr = DateFormat.Hm().format(expected.start);
          final endStr = DateFormat.Hm().format(expected.end);

          return Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.schedule_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$startStr – $endStr',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 17,
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Turno previsto',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.tertiary,
                      ),
                    ),
                  ],
                ),
              ),
              // Contador (faltan / vas tarde)
              Obx(() {
                final counter = controller.scheduleCounterText.value;
                if (counter == null || counter.isEmpty) {
                  return const SizedBox.shrink();
                }
                final late = controller.isLateForShift;
                final color = late
                    ? theme.colorScheme.error
                    : theme.colorScheme.tertiary;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        late ? 'Vas tarde' : 'Empieza en',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        late ? '+$counter' : counter,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Fichajes de hoy (línea de tiempo)
// ─────────────────────────────────────────────────────────────
class _TodayClockingsCard extends StatelessWidget {
  const _TodayClockingsCard({required this.controller});
  final EmployeeMyDayController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BaseCard(
      title: 'Fichajes de hoy',
      children: [
        const SizedBox(height: 4),
        Obx(() {
          // Aplanamos cada turno en eventos de entrada/salida ordenados.
          final events = <_ClockEvent>[];
          for (final e in controller.todayEntries) {
            events.add(_ClockEvent(time: e.clockIn, isEntry: true));
            if (e.clockOut != null) {
              events.add(_ClockEvent(time: e.clockOut!, isEntry: false));
            }
          }
          events.sort((a, b) => a.time.compareTo(b.time));

          if (events.isEmpty) {
            return Row(
              children: [
                Icon(
                  Icons.touch_app_outlined,
                  size: 20,
                  color: theme.colorScheme.tertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Por ahora no has fichado hoy.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                ),
              ],
            );
          }

          return Column(
            children: List.generate(events.length, (i) {
              final ev = events[i];
              final isLast = i == events.length - 1;
              return _ClockEventRow(event: ev, isLast: isLast);
            }),
          );
        }),
      ],
    );
  }
}

class _ClockEvent {
  final DateTime time;
  final bool isEntry;
  _ClockEvent({required this.time, required this.isEntry});
}

class _ClockEventRow extends StatelessWidget {
  const _ClockEventRow({required this.event, required this.isLast});
  final _ClockEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = event.isEntry
        ? theme.colorScheme.primary
        : theme.colorScheme.error;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  event.isEntry ? Icons.login_rounded : Icons.logout_rounded,
                  size: 16,
                  color: color,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: theme.colorScheme.outline),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 5, bottom: isLast ? 0 : 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    event.isEntry ? 'Entrada' : 'Salida',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    DateFormat.Hm().format(event.time),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Barra inferior: botón contextual de fichaje
// ─────────────────────────────────────────────────────────────
class _ClockActionBar extends StatelessWidget {
  const _ClockActionBar({required this.controller});
  final EmployeeMyDayController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Obx(() {
            final active = controller.currentEntry.value != null;
            return BlockButton(
              onPressed: active ? controller.clockOut : controller.clockIn,
              height: 52,
              borderRadius: 14,
              color: active
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
              assetPath: null,
              label: active ? 'FICHAR SALIDA' : 'FICHAR ENTRADA',
            );
          }),
        ),
      ),
    );
  }
}
