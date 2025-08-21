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
        title: const Text('farmatime', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: Obx(() {
        if (controller.isLoading.value) return const Center(child: CircularProgressIndicator());
        return RefreshIndicator(
          onRefresh: controller.refreshAll,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _EmployeesCard(controller: controller),
              const SizedBox(height: 12),
              _IncoherentCard(controller: controller),
              const SizedBox(height: 12),
              const _SubscriptionCard(),
              const SizedBox(height: 12),
              _CompanyInfoCard(controller: controller),
              const SizedBox(height: 24),
            ],
          ),
        );
      }),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(title, style: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700))),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _EmployeesCard extends StatelessWidget {
  const _EmployeesCard({required this.controller});
  final CompanyDashboardController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader('Empleados', trailing: Icon(Icons.edit, size: 18, color: theme.colorScheme.outline)),
            const SizedBox(height: 8),
            if (controller.working.isNotEmpty) ...[
              Text('Trabajando', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              ...controller.working.map((e) => _EmployeeTile(row: e, warn: false)),
              const SizedBox(height: 8),
            ],
            Divider(height: 16, color: theme.colorScheme.outlineVariant),
            if (controller.absent.isNotEmpty) ...[
              Text('Ausentes', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              ...controller.absent.map((e) => _EmployeeTile(row: e, warn: true)),
              const SizedBox(height: 8),
            ],
            Divider(height: 16, color: theme.colorScheme.outlineVariant),
            Text('Sin trabajar', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            if (controller.off.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('—', style: theme.textTheme.bodyMedium!.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              )
            else
              ...controller.off.map((e) => _EmployeeTile(row: e, muted: true)),
          ],
        ),
      ),
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  const _EmployeeTile({required this.row, this.warn = false, this.muted = false});
  final EmployeeRow row;
  final bool warn;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtle = theme.colorScheme.onSurfaceVariant;

    final controller = Get.find<CompanyDashboardController>();

    final right = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(warn ? Icons.logout_rounded : Icons.autorenew_rounded, size: 18, color: warn ? theme.colorScheme.error : theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          row.lastClockIn != null
              ? controller.relTimeFrom(row.lastClockIn!) // not used; Hack avoided by manual text:
              : (row.expected != null && DateTime.now().isAfter(row.expected!.start)
                  ? 'Hace ${DateTime.now().difference(row.expected!.start).inMinutes}m'
                  : ''),
          style: (warn
              ? theme.textTheme.bodyMedium!.copyWith(color: theme.colorScheme.error)
              : theme.textTheme.bodyMedium!.copyWith(color: theme.colorScheme.primary)),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: row.emp.photoUrl != null ? NetworkImage(row.emp.photoUrl!) : null,
            child: row.emp.photoUrl == null ? Text(row.emp.name.isNotEmpty ? row.emp.name[0] : '?') : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.emp.name, style: muted ? theme.textTheme.bodyLarge!.copyWith(color: subtle) : theme.textTheme.bodyLarge),
                Text(row.emp.position ?? 'Empleado', style: theme.textTheme.bodySmall!.copyWith(color: subtle)),
              ],
            ),
          ),
          if (!muted) right,
        ],
      ),
    );
  }
}

class _IncoherentCard extends StatelessWidget {
  const _IncoherentCard({required this.controller});
  final CompanyDashboardController controller;

  String _fmtDate(DateTime d) => DateFormat('d/M/yyyy').format(d);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader('Marcajes incoherentes', trailing: Icon(Icons.group, size: 18, color: theme.colorScheme.outline)),
            const SizedBox(height: 8),
            if (controller.incoherent.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('Sin alertas por ahora', style: theme.textTheme.bodyMedium!.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              )
            else
              ...controller.incoherent.map((a) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        CircleAvatar(radius: 18, child: Text(a.emp.name.isNotEmpty ? a.emp.name[0] : '?')),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.emp.name, style: theme.textTheme.bodyLarge),
                              Text(_fmtDate(a.date), style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Ausencia', style: theme.textTheme.bodyMedium!.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.w600)),
                            Text('-${a.deltaMinutes}m', style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.error)),
                          ],
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader('Suscripción', trailing: Icon(Icons.edit, size: 18, color: theme.colorScheme.outline)),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.group, color: accent),
                const SizedBox(width: 8),
                Text('9/9', style: theme.textTheme.titleLarge!.copyWith(color: accent)),
              ],
            ),
            const SizedBox(height: 10),
            Text('Próxima renovación', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 6),
            Text('12/06/2025', style: theme.textTheme.headlineSmall!.copyWith(color: accent, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          ],
        ),
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
    final subtle = theme.colorScheme.onSurfaceVariant;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader('Datos de la empresa', trailing: Icon(Icons.edit, size: 18, color: theme.colorScheme.outline)),
            const SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: controller.brain.company.value?.logoUrl != null ? NetworkImage(controller.brain.company.value!.logoUrl!) : null,
                  child: controller.brain.company.value?.logoUrl == null
                      ? Text(controller.brain.company.value?.legalName.isNotEmpty == true ? controller.brain.company.value!.legalName[0] : '?')
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.brain.company.value?.legalName ?? '—',
                        style: theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        controller.brain.company.value?.email ?? '—',
                        style: theme.textTheme.bodyMedium!.copyWith(color: subtle),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _kv(theme, 'CIF', controller.brain.company.value?.vatNumber ?? '—'),
            const SizedBox(height: 6),
            _kv(theme, 'Dirección', controller.brain.company.value?.address?.address != null ? controller.brain.company.value!.address!.address : '—'),
            const SizedBox(height: 6),
            _kv(theme, 'Ciudad', controller.brain.company.value?.address?.city != null ? controller.brain.company.value!.address!.city : '—'),
          ],
        ),
      ),
    );
  }

  Widget _kv(ThemeData theme, String k, String v) => Row(
        children: [
          SizedBox(width: 90, child: Text(k, style: theme.textTheme.bodySmall)),
          Expanded(child: Text(v, style: theme.textTheme.bodyMedium)),
        ],
      );
}
