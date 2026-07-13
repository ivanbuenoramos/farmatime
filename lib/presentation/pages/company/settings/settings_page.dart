import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/presentation/pages/company/settings/settings_controller.dart';

class SettingsPage extends GetView<SettingsController> {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final trailing = Icon(Icons.chevron_right_rounded, color: Get.theme.colorScheme.outline);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        titleSpacing: 0,
        centerTitle: false,
      ),
      body: Obx(
        () => Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SizedBox(
                height: Get.height - MediaQuery.of(context).padding.vertical - kToolbarHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Section(
                      title: 'General',
                      children: [
                        _Tile(
                          leading: Icon(Icons.notifications_none_rounded, color: Get.theme.colorScheme.primary),
                          title: 'Notificaciones',
                          trailing: trailing,
                          onTap: () => Get.toNamed(Routes.companyNotifications),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Ajustes de la app',
                      children: [
                        // _Tile(
                        //   leading: Icon(Icons.language_rounded, color: Get.theme.colorScheme.primary),
                        //   title: 'Idioma',
                        //   subtitle: controller.languageName(controller.currentLocale.value),
                        //   trailing: const Icon(Icons.chevron_right_rounded),
                        //   onTap: () => _showLanguageSheet(context),
                        // ),
                        // _DividerInset(),
                        _Tile(
                          leading: Icon(Icons.app_settings_alt_rounded, color: Get.theme.colorScheme.primary),
                          title: 'Permisos del dispositivo',
                          subtitle: controller.platformSettingsHint,
                          trailing: trailing,
                          onTap: controller.openSystemSettings,
                        ),
                        _DividerInset(),
                        _Tile(
                          leading: Icon(Icons.password_rounded, color: Get.theme.colorScheme.primary),
                          title: 'Cambiar contraseña',
                          subtitle: 'Actualizar la contraseña de la cuenta',
                          trailing: trailing,
                          onTap: controller.redirectToChangePassword,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Más información y ayuda',
                      children: [
                        _Tile(
                          leading: Icon(Icons.policy_outlined, color: Get.theme.colorScheme.primary),
                          title: 'Política de privacidad',
                          trailing: Icon(Icons.open_in_new_rounded, color: Get.theme.colorScheme.outline),
                          // onTap: controller.openPrivacy,
                        ),
                        _DividerInset(),
                        _Tile(
                          leading: Icon(Icons.description_outlined, color: Get.theme.colorScheme.primary),
                          title: 'Términos y condiciones de uso',
                          trailing: Icon(Icons.open_in_new_rounded, color: Get.theme.colorScheme.outline),
                          // onTap: controller.openTerms,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Spacer(),
                    _Section(
                      children: [
                        _Tile(
                          leading: Icon(Icons.logout_rounded, color: Get.theme.colorScheme.error),
                          title: 'Cerrar sesión',
                          trailing: trailing,
                          onTap: controller.logOut,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        controller.appVersion.value,
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Overlay de carga para acciones críticas
            if (controller.isBusy.value)
              Container(
                color: Colors.black.withOpacity(0.4),
                alignment: Alignment.center,
                child: const CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}

/// ====== UI helpers (tiles/sections) ======

class _Section extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const _Section({this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(
              title!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: const Color(0xffE5E5E5)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _Tile({
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              SizedBox(width: 28, height: 28, child: Center(child: leading)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ?? const SizedBox(),
            ],
          ),
        ),
      ),
    );
  }
}

class _DividerInset extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 52);
  }
}