import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/presentation/pages/employee/profile/employee_profile_controller.dart';
import 'package:farmatime/presentation/widgets/card/base_card.dart';
import 'package:farmatime/presentation/widgets/card/profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class EmployeeProfilePage extends GetView<EmployeeProfileController> {
  const EmployeeProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar perfil'),
        titleSpacing: 16,
      ),
      bottomNavigationBar: _SaveBar(controller: controller),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        children: [
          // Avatar editable
          Center(child: _AvatarPicker(controller: controller)),
          const SizedBox(height: 20),

          // Datos editables
          BaseCard(
            title: 'Datos personales',
            children: [
              const SizedBox(height: 4),
              _LabeledField(
                label: 'Nombre completo',
                icon: Icons.badge_outlined,
                controller: controller.nameController,
                hint: 'Tu nombre y apellidos',
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              _ReadOnlyRow(
                icon: Icons.mail_outline_rounded,
                label: 'Email',
                value: controller.emailController.text.isEmpty
                    ? '—'
                    : controller.emailController.text,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Información laboral (solo lectura)
          _WorkInfoCard(theme: theme),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Avatar con botón de cámara y spinner de subida
// ─────────────────────────────────────────────────────────────
class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({required this.controller});
  final EmployeeProfileController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final employee = controller.brain.employee.value;

    return Column(
      children: [
        Obx(() {
          final url = controller.photoUrl.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: controller.isUploadingLogo.value
                    ? null
                    : controller.pickLogo,
                child: ProfileAvatar(
                  imageUrl: url.isEmpty ? null : url,
                  name: controller.nameController.text.isEmpty
                      ? (employee?.name ?? '?')
                      : controller.nameController.text,
                  colorValue: employee?.avatarColor,
                  uid: employee?.uid,
                  size: 116,
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary,
                    border: Border.all(color: theme.colorScheme.surface, width: 3),
                  ),
                  padding: const EdgeInsets.all(7),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    size: 18,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
              if (controller.isUploadingLogo.value)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.35),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                ),
            ],
          );
        }),
        const SizedBox(height: 10),
        Text(
          'Toca la foto para cambiarla',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.tertiary,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Campo etiquetado
// ─────────────────────────────────────────────────────────────
class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.icon,
    required this.controller,
    this.hint,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String? hint;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.tertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          textCapitalization: textCapitalization,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20),
            hintText: hint,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Información laboral (solo lectura)
// ─────────────────────────────────────────────────────────────
class _WorkInfoCard extends StatelessWidget {
  const _WorkInfoCard({required this.theme});
  final ThemeData theme;

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
            : 'Otro';
    }
  }

  static String _workdayLabel(WorkdayType? w) {
    switch (w) {
      case WorkdayType.completa:
        return 'Jornada completa';
      case WorkdayType.media:
        return 'Media jornada';
      case null:
        return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final employee = Get.find<EmployeeProfileController>().brain.employee.value;
    if (employee == null) return const SizedBox.shrink();

    final hireDate =
        DateFormat("d 'de' MMMM y", 'es_ES').format(employee.hireDate);

    return BaseCard(
      title: 'Información laboral',
      children: [
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.lock_outline_rounded,
                size: 14, color: theme.colorScheme.tertiary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Estos datos los gestiona tu empresa.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ReadOnlyRow(
          icon: Icons.work_outline_rounded,
          label: 'Puesto',
          value: _roleLabel(employee),
        ),
        const SizedBox(height: 12),
        _ReadOnlyRow(
          icon: Icons.schedule_rounded,
          label: 'Jornada',
          value: _workdayLabel(employee.workdayType),
        ),
        const SizedBox(height: 12),
        _ReadOnlyRow(
          icon: Icons.event_rounded,
          label: 'Fecha de alta',
          value: hireDate,
        ),
      ],
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.tertiary),
        const SizedBox(width: 10),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.tertiary,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Barra inferior con botón de guardar
// ─────────────────────────────────────────────────────────────
class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.controller});
  final EmployeeProfileController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Obx(
            () => FilledButton.icon(
              onPressed: controller.isSaving.value ? null : controller.saveChanges,
              icon: controller.isSaving.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(
                controller.isSaving.value ? 'Guardando…' : 'Guardar cambios',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
