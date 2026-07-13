// lib/presentation/pages/company/upsert_employee/upsert_employee_page.dart
import 'package:farmatime/presentation/presentation.dart';
import 'package:farmatime/presentation/widgets/card/base_card.dart';
import 'package:farmatime/presentation/widgets/card/profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:farmatime/data/models/employee_model.dart';

class UpsertEmployeePage extends GetView<UpsertEmployeeController> {
  const UpsertEmployeePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      final isEdit = controller.isEdit;
      final isLoading = controller.isLoading.value;

      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final ok = await _confirmLeave(context);
          if (ok && context.mounted) Navigator.of(context).pop();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () async {
                final ok = await _confirmLeave(context);
                if (ok && context.mounted) Navigator.of(context).pop();
              },
            ),
            title: Text(isEdit ? 'Editar empleado' : 'Nuevo empleado'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(theme: theme),
                const SizedBox(height: 16),
                _BasicDataCard(theme: theme, isEdit: isEdit),
                const SizedBox(height: 12),
                _WorkInfoCard(theme: theme),
                const SizedBox(height: 12),
                _LeaveCard(theme: theme),
              ],
            ),
          ),
          bottomNavigationBar: _SubmitBar(isEdit: isEdit, isLoading: isLoading),
        ),
      );
    });
  }

  Future<bool> _confirmLeave(BuildContext context) async {
    if (!controller.hasChanges) return true;
    final theme = Theme.of(context);

    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambios sin guardar'),
        content: const Text('Tienes cambios sin guardar. ¿Quieres salir?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: Text(
              'Seguir editando',
              style: TextStyle(color: theme.colorScheme.secondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: Text(
              'Salir sin guardar',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
    return res == 'discard';
  }
}

// ─────────────────────────────────────────────────────────────
// Cabecera: avatar + nombre + estado
// ─────────────────────────────────────────────────────────────
class _Header extends GetView<UpsertEmployeeController> {
  const _Header({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            Color.lerp(theme.colorScheme.primary, Colors.black, 0.18)!,
          ],
        ),
      ),
      child: Column(
        children: [
          _AvatarEditor(theme: theme),
          const SizedBox(height: 12),
          GetBuilder<UpsertEmployeeController>(
            builder: (c) {
              final name = c.nameController.text.trim();
              return Text(
                name.isNotEmpty
                    ? name
                    : (c.isEdit
                          ? (c.originalEmployee?.name ?? '')
                          : 'Nuevo empleado'),
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              );
            },
          ),
          if (controller.isEdit) ...[
            const SizedBox(height: 8),
            _StatusChip(status: controller.originalEmployee?.accountStatus),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              'Completa los datos para darlo de alta',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _AvatarEditor extends GetView<UpsertEmployeeController> {
  const _AvatarEditor({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<UpsertEmployeeController>(
      builder: (_) {
        return Obx(() {
          final photoUrl = controller.photoUrl.value;
          final name = controller.nameController.text.trim();
          final canEdit = controller.isEdit;

          return GestureDetector(
            onTap: controller.isUploadingPhoto.value || !canEdit
                ? null
                : controller.pickPhoto,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.7),
                      width: 3,
                    ),
                  ),
                  child: ProfileAvatar(
                    name: name.isEmpty ? '?' : name,
                    imageUrl: photoUrl.isEmpty ? null : photoUrl,
                    colorValue: controller.originalEmployee?.avatarColor,
                    size: 96,
                  ),
                ),
                if (canEdit)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4),
                        ],
                      ),
                      child: controller.isUploadingPhoto.value
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.primary,
                              ),
                            )
                          : Icon(
                              Icons.photo_camera_rounded,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                    ),
                  ),
              ],
            ),
          );
        });
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final EmployeeAccountStatus? status;

  @override
  Widget build(BuildContext context) {
    if (status == null) return const SizedBox.shrink();

    final ({String label, Color color}) info = switch (status!) {
      EmployeeAccountStatus.pending => (
        label: 'Pendiente',
        color: const Color(0xffFFC65C),
      ),
      EmployeeAccountStatus.active => (
        label: 'Activo',
        color: const Color(0xff35E08B),
      ),
      EmployeeAccountStatus.inactive => (
        label: 'Inactivo (impago)',
        color: Colors.white70,
      ),
      EmployeeAccountStatus.disabled => (
        label: 'Deshabilitado',
        color: const Color(0xffFF8A8A),
      ),
      EmployeeAccountStatus.deleted => (
        label: 'Eliminado',
        color: Colors.white60,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 9, color: info.color),
          const SizedBox(width: 6),
          Text(
            info.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Datos básicos
// ─────────────────────────────────────────────────────────────
class _BasicDataCard extends GetView<UpsertEmployeeController> {
  const _BasicDataCard({required this.theme, required this.isEdit});
  final ThemeData theme;
  final bool isEdit;

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      title: 'Datos básicos',
      children: [
        const SizedBox(height: 12),
        TextField(
          controller: controller.nameController,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => controller.update(),
          decoration: const InputDecoration(
            labelText: 'Nombre del empleado',
            hintText: 'Ej: María García',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller.emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'Correo electrónico',
            hintText: 'Ej: maria@empresa.com',
            prefixIcon: const Icon(Icons.mail_outline_rounded),
            // Indicador de disponibilidad (solo al crear).
            suffixIcon: isEdit
                ? null
                : Obx(
                    () =>
                        _EmailStatusIcon(status: controller.emailStatus.value),
                  ),
          ),
        ),
        if (!isEdit)
          Obx(() => _EmailStatusHint(status: controller.emailStatus.value)),
      ],
    );
  }
}

class _EmailStatusIcon extends StatelessWidget {
  const _EmailStatusIcon({required this.status});
  final EmailFieldStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case EmailFieldStatus.checking:
        return const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case EmailFieldStatus.available:
        return const Icon(Icons.check_circle_rounded, color: Color(0xff16A34A));
      case EmailFieldStatus.alreadyInUse:
      case EmailFieldStatus.invalidFormat:
        return Icon(
          Icons.error_outline_rounded,
          color: Theme.of(context).colorScheme.error,
        );
      case EmailFieldStatus.error:
        return const Icon(
          Icons.warning_amber_rounded,
          color: Color(0xffF59E0B),
        );
      case EmailFieldStatus.idle:
        return const SizedBox.shrink();
    }
  }
}

class _EmailStatusHint extends StatelessWidget {
  const _EmailStatusHint({required this.status});
  final EmailFieldStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final IconData icon;
    final Color color;
    final String label;

    switch (status) {
      case EmailFieldStatus.idle:
      case EmailFieldStatus.checking:
        return const SizedBox.shrink();
      case EmailFieldStatus.available:
        icon = Icons.check_circle_rounded;
        color = const Color(0xff16A34A);
        label = 'Correo disponible';
        break;
      case EmailFieldStatus.invalidFormat:
        icon = Icons.error_outline_rounded;
        color = theme.colorScheme.error;
        label = 'El formato del correo no es válido';
        break;
      case EmailFieldStatus.alreadyInUse:
        icon = Icons.cancel_rounded;
        color = theme.colorScheme.error;
        label = 'Ya existe una cuenta con ese correo';
        break;
      case EmailFieldStatus.error:
        icon = Icons.warning_amber_rounded;
        color = const Color(0xffF59E0B);
        label = 'No se pudo comprobar el correo';
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Información laboral
// ─────────────────────────────────────────────────────────────
class _WorkInfoCard extends GetView<UpsertEmployeeController> {
  const _WorkInfoCard({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      title: 'Información laboral',
      children: [
        const SizedBox(height: 12),
        TextField(
          controller: controller.hourlyRateController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Precio por hora',
            hintText: 'Ej: 12,50',
            prefixIcon: Icon(Icons.payments_outlined),
            suffixText: '€/h',
          ),
        ),
        const SizedBox(height: 16),
        Obx(
          () => DropdownButtonFormField<EmployeeRole>(
            initialValue: controller.role.value,
            isExpanded: true,
            borderRadius: BorderRadius.circular(12),
            decoration: const InputDecoration(
              labelText: 'Cargo',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            items: const [
              DropdownMenuItem(
                value: EmployeeRole.tecnico,
                child: Text('Técnico de farmacia'),
              ),
              DropdownMenuItem(
                value: EmployeeRole.auxiliar,
                child: Text('Auxiliar de farmacia'),
              ),
              DropdownMenuItem(
                value: EmployeeRole.farmaceutico,
                child: Text('Farmacéutico'),
              ),
              DropdownMenuItem(
                value: EmployeeRole.otro,
                child: Text('Otro (especificar)'),
              ),
            ],
            onChanged: (v) {
              controller.role.value = v ?? EmployeeRole.tecnico;
              controller.update();
            },
          ),
        ),
        Obx(() {
          if (controller.role.value != EmployeeRole.otro) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextField(
              controller: controller.roleOtherController,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Especifica el cargo',
                hintText: 'Indica el puesto',
                prefixIcon: Icon(Icons.edit_outlined),
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        Obx(
          () => DropdownButtonFormField<WorkdayType?>(
            initialValue: controller.workdayType.value,
            isExpanded: true,
            borderRadius: BorderRadius.circular(12),
            decoration: const InputDecoration(
              labelText: 'Tipo de jornada (opcional)',
              prefixIcon: Icon(Icons.schedule_rounded),
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('Sin especificar')),
              DropdownMenuItem(
                value: WorkdayType.completa,
                child: Text('Jornada completa'),
              ),
              DropdownMenuItem(
                value: WorkdayType.media,
                child: Text('Media jornada'),
              ),
            ],
            onChanged: (v) {
              controller.workdayType.value = v;
              controller.update();
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Vacaciones y asuntos propios
// ─────────────────────────────────────────────────────────────
class _LeaveCard extends GetView<UpsertEmployeeController> {
  const _LeaveCard({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      title: 'Vacaciones y asuntos propios',
      description:
          'Define cómo acumula días libres. Las vacaciones se generan según los días trabajados.',
      children: [
        const SizedBox(height: 12),
        TextField(
          controller: controller.vacationPer30Controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Vacaciones por cada 30 días trabajados',
            hintText: 'Ej: 2,5',
            prefixIcon: Icon(Icons.beach_access_rounded),
            suffixText: 'días',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller.personalPerYearController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Asuntos propios por año',
            hintText: 'Ej: 2',
            prefixIcon: Icon(Icons.event_available_rounded),
            suffixText: 'días',
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Barra inferior con el CTA principal
// ─────────────────────────────────────────────────────────────
class _SubmitBar extends GetView<UpsertEmployeeController> {
  const _SubmitBar({required this.isEdit, required this.isLoading});
  final bool isEdit;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: FilledButton.icon(
          onPressed: isLoading ? null : controller.onSubmit,
          icon: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  isEdit ? Icons.save_rounded : Icons.person_add_rounded,
                  size: 20,
                ),
          label: Text(
            isLoading
                ? 'Guardando…'
                : (isEdit ? 'Guardar cambios' : 'Crear empleado'),
          ),
        ),
      ),
    );
  }
}
