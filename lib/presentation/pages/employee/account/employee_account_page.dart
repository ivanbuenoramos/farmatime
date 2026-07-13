import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/presentation/pages/employee/account/employee_account_controller.dart';
import 'package:farmatime/presentation/widgets/card/profile_avatar.dart';

class EmployeeAccountPage extends StatelessWidget {
  const EmployeeAccountPage({super.key});

  static String _roleLabel(EmployeeModel e) {
    switch (e.role) {
      case EmployeeRole.auxiliar:
        return 'Auxiliar de farmacia';
      case EmployeeRole.farmaceutico:
        return 'Farmacéutico';
      case EmployeeRole.tecnico:
        return 'Técnico de farmacia';
      case EmployeeRole.otro:
        return (e.roleOther?.trim().isNotEmpty ?? false)
            ? e.roleOther!.trim()
            : 'Empleado';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = Get.find<EmployeeAccountController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi cuenta'),
        titleSpacing: 16,
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Cabecera con avatar y datos
          Obx(() {
            final emp = controller.brain.employee.value;
            return _ProfileHeader(
              name: emp?.name ?? '',
              email: emp?.email ?? '',
              role: emp != null ? _roleLabel(emp) : '',
              photoUrl: controller.logoUrl.value.isEmpty
                  ? emp?.photoUrl
                  : controller.logoUrl.value,
              avatarColor: emp?.avatarColor,
              uid: emp?.uid,
            );
          }),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            child: Column(
              children: [
                // Ajustes
                _MenuGroup(
                  children: [
                    _MenuTile(
                      icon: Icons.person_rounded,
                      iconColor: theme.colorScheme.primary,
                      title: 'Editar perfil',
                      subtitle: 'Nombre, foto y email',
                      onTap: controller.redirectToProfile,
                    ),
                    _MenuTile(
                      icon: Icons.lock_rounded,
                      iconColor: theme.colorScheme.primary,
                      title: 'Cambiar contraseña',
                      subtitle: 'Actualiza la contraseña de tu cuenta',
                      onTap: controller.redirectToChangePassword,
                    ),
                    _MenuTile(
                      icon: Icons.settings_rounded,
                      iconColor: theme.colorScheme.primary,
                      title: 'Configuración',
                      subtitle: 'Ajustes de la aplicación',
                      onTap: controller.redirectToSettings,
                      isLast: true,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Cerrar sesión
                _MenuGroup(
                  children: [
                    _MenuTile(
                      icon: Icons.logout_rounded,
                      iconColor: theme.colorScheme.error,
                      title: 'Cerrar sesión',
                      titleColor: theme.colorScheme.error,
                      showChevron: false,
                      onTap: () => _confirmLogout(context, controller),
                      isLast: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(
      BuildContext context, EmployeeAccountController controller) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              controller.logOut();
            },
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Cabecera con banner y datos del empleado
// ─────────────────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.role,
    required this.photoUrl,
    required this.avatarColor,
    required this.uid,
  });

  final String name;
  final String email;
  final String role;
  final String? photoUrl;
  final int? avatarColor;
  final String? uid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outline),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        children: [
          ProfileAvatar(
            name: name.isEmpty ? '?' : name,
            imageUrl: (photoUrl == null || photoUrl!.isEmpty) ? null : photoUrl,
            colorValue: avatarColor,
            uid: uid,
            size: 92,
          ),
          const SizedBox(height: 12),
          Text(
            name.isEmpty ? '—' : name,
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (role.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                role,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (email.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              email,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.tertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Grupo de opciones (tarjeta)
// ─────────────────────────────────────────────────────────────
class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.iconColor,
    this.titleColor,
    this.showChevron = true,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final Color? titleColor;
  final VoidCallback onTap;
  final bool showChevron;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = iconColor ?? theme.colorScheme.primary;

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: titleColor ?? theme.colorScheme.secondary,
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
                if (showChevron)
                  Icon(Icons.chevron_right_rounded,
                      color: theme.colorScheme.tertiary),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(height: 1, indent: 64, color: theme.colorScheme.outline),
      ],
    );
  }
}
