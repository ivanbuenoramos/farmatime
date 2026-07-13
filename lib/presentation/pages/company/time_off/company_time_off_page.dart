import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:farmatime/core/utils/leave_dates_utils.dart';
import 'package:farmatime/data/models/schedule/time_off_model.dart';
import 'package:farmatime/presentation/widgets/card/base_card.dart';
import 'package:farmatime/presentation/widgets/card/profile_avatar.dart';

import 'company_time_off_controller.dart';

class CompanyTimeOffPage extends GetView<CompanyTimeOffController> {
  const CompanyTimeOffPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitudes de ausencia'),
        titleSpacing: 16,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = controller.visible;
        final pendingCount = controller.pending.length;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SegmentedButton<TimeOffFilter>(
                segments: [
                  ButtonSegment(
                    value: TimeOffFilter.pending,
                    label: Text('Pendientes${pendingCount > 0 ? ' ($pendingCount)' : ''}'),
                  ),
                  const ButtonSegment(
                    value: TimeOffFilter.history,
                    label: Text('Historial'),
                  ),
                ],
                selected: {controller.filter.value},
                onSelectionChanged: (s) => controller.setFilter(s.first),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          controller.filter.value == TimeOffFilter.pending
                              ? 'No hay solicitudes pendientes.'
                              : 'No hay solicitudes en el historial.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final r = items[i];
                        return _CompanyTimeOffTile(
                          request: r,
                          employeeName: controller.employeeName(r.employeeId),
                          photoUrl: _photoFor(r.employeeId),
                          onTap: () => controller.manage(context, r),
                        );
                      },
                    ),
            ),
          ],
        );
      }),
    );
  }

  String? _photoFor(String employeeId) {
    final emp = controller.brain.companyEmployees
        .firstWhereOrNull((e) => e.uid == employeeId);
    return emp?.photoUrl;
  }
}

class _CompanyTimeOffTile extends StatelessWidget {
  final TimeOffModel request;
  final String employeeName;
  final String? photoUrl;
  final VoidCallback onTap;

  const _CompanyTimeOffTile({
    required this.request,
    required this.employeeName,
    required this.photoUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color statusColor = switch (request.status) {
      TimeOffStatus.requested => theme.colorScheme.secondary,
      TimeOffStatus.proposed => theme.colorScheme.primary,
      TimeOffStatus.approved => const Color(0xff35B58D),
      TimeOffStatus.rejected => theme.colorScheme.error,
      TimeOffStatus.cancelled => theme.colorScheme.outline,
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: BaseCard(
      children: [
        Row(
          children: [
            ProfileAvatar(
              imageUrl: photoUrl,
              name: employeeName,
              uid: request.employeeId,
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(employeeName,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        request.type == TimeOffType.vacation
                            ? Icons.beach_access_rounded
                            : Icons.event_available_rounded,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${request.type.label} · ${formatDatesSummary(request.effectiveDates)}',
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
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
          ],
        ),
      ],
      ),
    );
  }
}
