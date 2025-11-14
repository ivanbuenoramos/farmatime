import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/core/utils/date_time_utils.dart';
import 'package:farmatime/presentation/widgets/card/base_card.dart';
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
        return RefreshIndicator(
          onRefresh: controller.refreshAll,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: theme.textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.w700))),
            if (trailing != null) trailing!,
          ],
        ),
        Divider(),
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
    return BaseCard(
      children: [
        _SectionHeader('Empleados', trailing: Icon(Icons.edit, size: 18, color: theme.colorScheme.outline)),
        const SizedBox(height: 8),
        Text('Trabajando', style: theme.textTheme.headlineSmall?.copyWith(fontSize: 14)),
        Divider(height: 16),
        if (controller.working.isNotEmpty) ...[
          ...controller.working.map((e) => _EmployeeTile(row: e, warn: false)),
          const SizedBox(height: 8),
          Divider(height: 16),
        ],
    
        Text('Ausentes', style: theme.textTheme.headlineSmall?.copyWith(fontSize: 14)),
        Divider(height: 16),
        if (controller.absent.isNotEmpty) ...[
          ...controller.absent.map((e) => _EmployeeTile(row: e, warn: true)),
          const SizedBox(height: 8),
        ],
        Text('Sin trabajar', style: theme.textTheme.headlineSmall?.copyWith(fontSize: 14)),
        Divider(height: 16),
        if (controller.off.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('—', style: theme.textTheme.bodyMedium!.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          )
        else
          ...controller.off.map((e) => _EmployeeTile(row: e, muted: true)),
      ],
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
                  : 'Sin fichar'),
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
                Text(row.emp.name, style: muted ? theme.textTheme.headlineSmall?.copyWith(fontSize: 14) : theme.textTheme.bodyLarge),
                Text(row.emp.position ?? 'Empleado', style: theme.textTheme.bodySmall),
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
    return BaseCard(
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
    );
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

    final DateTimeUtils dateTimeUtils = DateTimeUtils();

    return GestureDetector(
      onTap: () => Get.toNamed(Routes.companySubscription),
      child: BaseCard(
        children: [
          _SectionHeader('Suscripción', trailing: Icon(Icons.edit, size: 18, color: theme.colorScheme.outline)),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.group, 
                color: Get.theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '${controller.companyEmployeesController.employees.length}/${controller.brain.company.value?.contractedSeats}', 
                style: theme.textTheme.titleLarge!.copyWith(
                  color: Get.theme.colorScheme.primary,
                )
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Próxima renovación', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text(
            dateTimeUtils.formatDateToString(controller.brain.company.value!.currentPeriodEnd!), 
            style: theme.textTheme.headlineSmall!.copyWith(
              color: Get.theme.colorScheme.primary, 
              fontWeight: FontWeight.w700, 
              letterSpacing: -0.5)
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

    return GestureDetector(
      onTap: controller.redirectToComapnyProfile,
      child: BaseCard(
        children: [
          _SectionHeader('Datos de la empresa', trailing: Icon(Icons.edit, size: 18, color: theme.colorScheme.outline)),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(
                radius: 22,
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
                      style: theme.textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      controller.brain.company.value?.email ?? '—',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _kv(theme, 'CIF', controller.brain.company.value?.vatNumber ?? '—'),
          const SizedBox(height: 4),
          _kv(theme, 'Dirección', controller.brain.company.value?.address?.address != null ? controller.brain.company.value!.address!.address : '—'),
          const SizedBox(height: 4),
          _kv(theme, 'Ciudad', controller.brain.company.value?.address?.city != null ? controller.brain.company.value!.address!.city : '—'),
        ],
      ),
    );
  }

  Widget _kv(ThemeData theme, String k, String v) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(k, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.secondary)),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              height: 1,
              color: theme.dividerColor,
            ),
          ),
          const SizedBox(width: 4),
          Text(v, style: theme.textTheme.bodyMedium),
        ],
      );
}
