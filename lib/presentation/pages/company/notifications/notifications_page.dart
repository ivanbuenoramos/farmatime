import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:farmatime/presentation/pages/company/notifications/notifications_controller.dart';

class NotificationsPage extends GetView<NotificationsController> {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        titleSpacing: 0,
        centerTitle: false,
      ),
      body: SafeArea(
        child: Obx(
          () => SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!controller.systemPermissionGranted.value) ...[
                  _PermissionBanner(onTap: controller.requestSystemPermission),
                  const SizedBox(height: 12),
                ],

                _Section(
                  title: 'General',
                  children: [
                    _SwitchTile(
                      leading: Icons.notifications_active_rounded,
                      title: 'Notificaciones push',
                      subtitle: controller.pushEnabled.value
                          ? 'Recibirás avisos importantes en tu dispositivo'
                          : 'No recibirás avisos en tu dispositivo',
                      value: controller.pushEnabled.value,
                      onChanged: controller.togglePush,
                    ),
                    _DividerInset(),
                    _Tile(
                      leading: Icon(
                        Icons.app_settings_alt_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      title: 'Permisos del sistema',
                      subtitle: controller.systemPermissionHint,
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: theme.colorScheme.outline,
                      ),
                      onTap: controller.openSystemSettings,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Cada rol ve solo los tipos de push que realmente recibe.
                _CategoryGroup(
                  title: 'Solicitudes',
                  enabled: controller.pushEnabled.value,
                  children: [
                    if (controller.isCompany)
                      _SwitchTile(
                        leading: Icons.beach_access_rounded,
                        title: 'Nuevas solicitudes',
                        subtitle:
                            'Cuando un empleado solicita una ausencia, la '
                            'cancela o responde a una propuesta',
                        value: controller.leaveRequests.value,
                        enabled: controller.pushEnabled.value,
                        onChanged: (v) =>
                            controller.toggle(controller.leaveRequests, v),
                      )
                    else
                      _SwitchTile(
                        leading: Icons.fact_check_rounded,
                        title: 'Estado de mis solicitudes',
                        subtitle: 'Cuando tu farmacia aprueba, rechaza o '
                            'propone otras fechas',
                        value: controller.leaveStatusUpdates.value,
                        enabled: controller.pushEnabled.value,
                        onChanged: (v) =>
                            controller.toggle(controller.leaveStatusUpdates, v),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                if (!controller.isCompany) ...[
                  _CategoryGroup(
                    title: 'Horarios',
                    enabled: controller.pushEnabled.value,
                    children: [
                      _SwitchTile(
                        leading: Icons.calendar_month_rounded,
                        title: 'Cambios de horario',
                        subtitle: 'Cambios en tus turnos y recordatorios '
                            'antes de empezar',
                        value: controller.scheduleChanges.value,
                        enabled: controller.pushEnabled.value,
                        onChanged: (v) =>
                            controller.toggle(controller.scheduleChanges, v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                _CategoryGroup(
                  title: 'Mensajes',
                  enabled: controller.pushEnabled.value,
                  children: [
                    _SwitchTile(
                      leading: Icons.chat_bubble_outline_rounded,
                      title: 'Nuevos mensajes',
                      subtitle: 'Mensajes recibidos en el chat',
                      value: controller.chatMessages.value,
                      enabled: controller.pushEnabled.value,
                      onChanged: (v) =>
                          controller.toggle(controller.chatMessages, v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Tipos operativos sin toggle propio: solo los desactiva el
                // interruptor general (deben coincidir con PREF_BY_TYPE en
                // functions/src/notifications/sendPush.js).
                _CategoryGroup(
                  title: 'Siempre activas',
                  enabled: controller.pushEnabled.value,
                  children: controller.isCompany
                      ? [
                          const _InfoTile(
                            leading: Icons.punch_clock_rounded,
                            title: 'Alertas de fichajes',
                            subtitle: 'Empleados sin fichar y fichajes '
                                'editados',
                          ),
                          _DividerInset(),
                          const _InfoTile(
                            leading: Icons.credit_card_rounded,
                            title: 'Suscripción y facturación',
                            subtitle: 'Pagos, renovaciones y avisos de plazas',
                          ),
                          _DividerInset(),
                          const _InfoTile(
                            leading: Icons.description_rounded,
                            title: 'Informes y empleados',
                            subtitle: 'Informe mensual listo y activación de '
                                'cuentas',
                          ),
                        ]
                      : [
                          const _InfoTile(
                            leading: Icons.punch_clock_rounded,
                            title: 'Alertas de fichajes',
                            subtitle: 'Olvidos de salida y fichajes editados '
                                'por tu farmacia',
                          ),
                          _DividerInset(),
                          const _InfoTile(
                            leading: Icons.description_rounded,
                            title: 'Informes y cuenta',
                            subtitle: 'Informe mensual listo y avisos sobre '
                                'tu cuenta',
                          ),
                        ],
                ),
                const SizedBox(height: 24),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Tus preferencias se guardan automáticamente.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _PermissionBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.error;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(Icons.notifications_off_rounded, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notificaciones bloqueadas',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Activa los permisos del sistema para recibir avisos.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryGroup extends StatelessWidget {
  final String title;
  final bool enabled;
  final List<Widget> children;

  const _CategoryGroup({
    required this.title,
    required this.enabled,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: IgnorePointer(
        ignoring: !enabled,
        child: _Section(title: title, children: children),
      ),
    );
  }
}

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
        if (title != null)
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
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
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

class _SwitchTile extends StatelessWidget {
  final IconData leading;
  final String title;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.leading,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: Center(
              child: Icon(leading, color: theme.colorScheme.primary),
            ),
          ),
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
          Switch.adaptive(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeThumbColor: theme.colorScheme.primary,
          ),
        ],
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

/// Fila informativa sin interruptor: tipos operativos que siempre se envían
/// (solo los apaga el toggle general de push).
class _InfoTile extends StatelessWidget {
  final IconData leading;
  final String title;
  final String? subtitle;

  const _InfoTile({
    required this.leading,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: Center(
              child: Icon(leading, color: theme.colorScheme.primary),
            ),
          ),
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
          Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}
