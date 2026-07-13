import 'package:farmatime/presentation/widgets/card/profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:farmatime/presentation/presentation.dart';

class CompanyAccountPage extends GetView<CompanyAccountController> {
  const CompanyAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() {
        final company = controller.brain.company.value;
        final emailNotVerified = company?.verifiedEmail == false;
        final billingStatus = company?.billingStatus;
        final billingProblem = billingStatus != null &&
            billingStatus != 'active' &&
            billingStatus != 'none' &&
            billingStatus != 'cancelled';

        return SingleChildScrollView(
          child: Column(
            children: [
              _ProfileHeader(controller: controller),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  children: [
                    _SettingsCard(
                      children: [
                        _SettingsTile(
                          icon: Icons.local_pharmacy_rounded,
                          title: 'Datos de la farmacia',
                          subtitle: 'Editar la información de la farmacia',
                          alert: emailNotVerified,
                          onTap: controller.redirectToProfile,
                        ),
                        const _TileDivider(),
                        _SettingsTile(
                          icon: Icons.subscriptions_rounded,
                          title: 'Gestionar suscripción',
                          subtitle: 'Ver y modificar tu plan',
                          alert: billingProblem,
                          alertColor: Theme.of(context).colorScheme.error,
                          onTap: controller.redirectToSubscription,
                        ),
                        const _TileDivider(),
                        _SettingsTile(
                          icon: Icons.picture_as_pdf_rounded,
                          title: 'Reportes de fichajes',
                          subtitle: 'Partes mensuales y PDFs',
                          onTap: controller.redirectToClockReports,
                        ),
                        const _TileDivider(),
                        _SettingsTile(
                          icon: Icons.settings_rounded,
                          title: 'Configuración',
                          subtitle: 'Ajustes de la aplicación',
                          onTap: controller.redirectToSettings,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SettingsCard(
                      children: [
                        _SettingsTile(
                          icon: Icons.logout_rounded,
                          title: 'Cerrar sesión',
                          danger: true,
                          showChevron: false,
                          onTap: controller.logOut,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// =====================================================================
// CABECERA DE PERFIL
// =====================================================================

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.controller});
  final CompanyAccountController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final company = controller.brain.company.value;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 24,
        16,
        24,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.82),
          ],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.25),
            ),
            child: ProfileAvatar(
              imageUrl: company?.logoUrl,
              name: company?.legalName ?? '—',
              size: 76,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            company?.legalName ?? '—',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            company?.email ?? '',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// TARJETA + TILES DE AJUSTES
// =====================================================================

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.alert = false,
    this.alertColor,
    this.danger = false,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool alert;
  final Color? alertColor;
  final bool danger;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color accent =
        danger ? theme.colorScheme.error : theme.colorScheme.primary;
    final Color dotColor = alertColor ?? const Color(0xffF59E0B);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: danger
                          ? theme.colorScheme.error
                          : theme.colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.tertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (alert) ...[
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
            ],
            if (showChevron)
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

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 64,
      color: Theme.of(context).colorScheme.outline,
    );
  }
}
