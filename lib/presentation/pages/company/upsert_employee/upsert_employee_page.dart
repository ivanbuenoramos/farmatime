// lib/presentation/pages/company/upsert_employee/upsert_employee_page.dart
import 'package:farmatime/presentation/presentation.dart';
import 'package:farmatime/presentation/widgets/card/base_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:farmatime/data/models/employee_model.dart';

class UpsertEmployeePage extends GetView<UpsertEmployeeController> {
  const UpsertEmployeePage({super.key});

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.characters.take(2).toString().toUpperCase();
    return (parts[0].isNotEmpty ? parts[0][0] : '') +
        (parts[1].isNotEmpty ? parts[1][0] : '');
  }

  Widget _statusChip(EmployeeAccountStatus? status, ThemeData theme) {
    if (status == null) return const SizedBox.shrink();

    String label;
    Color bg;
    Color fg;

    switch (status) {
      case EmployeeAccountStatus.pending:
        label = 'Pendiente';
        bg = Colors.orange.withOpacity(0.1);
        fg = Colors.orange;
        break;
      case EmployeeAccountStatus.active:
        label = 'Activo';
        bg = Colors.green.withOpacity(0.1);
        fg = Colors.green;
        break;
      case EmployeeAccountStatus.inactive:
        label = 'Inactivo (impago)';
        bg = Colors.amber.withOpacity(0.1);
        fg = Colors.amber[800]!;
        break;
      case EmployeeAccountStatus.disabled:
        label = 'Deshabilitado';
        bg = Colors.red.withOpacity(0.1);
        fg = Colors.red;
        break;
      case EmployeeAccountStatus.deleted:
        label = 'Eliminado';
        bg = Colors.grey.withOpacity(0.1);
        fg = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: fg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    InputDecoration decoration(String hint) => InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        );

    const spacing4 = SizedBox(height: 4);
    const spacing8 = SizedBox(height: 8);
    const spacing16 = SizedBox(height: 16);
    const spacing20 = SizedBox(height: 20);
    const spacing24 = SizedBox(height: 24);

    return Obx(() {
      final isEdit = controller.isEdit;
      final isLoading = controller.isLoading.value;

      return Scaffold(
        appBar: AppBar(
          title: Text(isEdit ? 'Editar empleado' : 'Nuevo empleado'),
          actions: [
            TextButton(
              onPressed: isLoading ? null : controller.onSubmit,
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      isEdit ? 'Guardar' : 'Crear',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
            ),
          ],
        ),
        // bottomNavigationBar: Container(
        //   width: double.infinity,
        //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        //   decoration: BoxDecoration(
        //     color: theme.scaffoldBackgroundColor,
        //     boxShadow: [
        //       BoxShadow(
        //         color: Colors.black.withOpacity(0.06),
        //         blurRadius: 10,
        //         offset: const Offset(0, -2),
        //       ),
        //     ],
          // ),
        //   child: SafeArea(
        //     child: FilledButton(
        //       onPressed: isLoading ? null : controller.onSubmit,
        //       style: FilledButton.styleFrom(
        //         padding: const EdgeInsets.symmetric(vertical: 14),
        //         shape: RoundedRectangleBorder(
        //           borderRadius: BorderRadius.circular(12),
        //         ),
        //       ),
        //       child: isLoading
        //           ? const SizedBox(
        //               width: 20,
        //               height: 20,
        //               child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        //             )
        //           : Text(isEdit ? 'Guardar cambios' : 'Crear empleado'),
        //     ),
        //   ),
        // ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER: avatar + nombre + estado
              Center(
                child: Column(
                  children: [
                    Obx(() {
                      final photoUrl = controller.photoUrl.value;
                      final name = controller.nameController.text.trim();
                      final hasName = name.isNotEmpty;

                      Widget avatarContent;
                      if (photoUrl.isNotEmpty) {
                        avatarContent = CircleAvatar(
                          radius: 50,
                          backgroundImage: NetworkImage(photoUrl),
                        );
                      } else {
                        avatarContent = CircleAvatar(
                          radius: 50,
                          backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                          child: Text(
                            hasName ? _initials(name) : '?',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        );
                      }

                      return GestureDetector(
                        onTap: controller.isUploadingPhoto.value
                            ? null
                            : controller.pickPhoto,
                        child: Stack(
                          children: [
                            avatarContent,
                            if (controller.isEdit)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: controller.isUploadingPhoto.value
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.edit_rounded,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                    spacing8,
                    Text(
                      controller.isEdit
                          ? (controller.originalEmployee?.name ?? '')
                          : 'Datos del nuevo empleado',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    spacing4,
                    if (controller.isEdit)
                      _statusChip(controller.originalEmployee?.accountStatus, theme),
                  ],
                ),
              ),
              spacing24,

              // CARD 1: Datos básicos
              BaseCard(
                title: 'Datos básicos',
                children: [
                  const SizedBox(height: 8),
                  const Text('Nombre del empleado'),
                  spacing4,
                  TextField(
                    controller: controller.nameController,
                    decoration: decoration('Ej: María García'),
                    textInputAction: TextInputAction.next,
                  ),
                  spacing20,
                  const Text('Correo electrónico'),
                  spacing4,
                  TextField(
                    controller: controller.emailController,
                    decoration: decoration('Ej: maria@empresa.com'),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                ],
              ),
              spacing16,

              // CARD 2: Información laboral
              BaseCard(
                title: 'Información laboral',
                children: [
                  const SizedBox(height: 8),
                  const Text('Precio por hora (€)'),
                  spacing4,
                  TextField(
                    controller: controller.hourlyRateController,
                    decoration: decoration('Ej: 12.50'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                  ),
                  spacing16,
                  const Text('Cargo'),
                  spacing4,
                  Obx(() {
                    return DropdownButtonFormField<EmployeeRole>(
                      value: controller.role.value,
                      decoration: decoration('Selecciona el cargo'),
                      borderRadius: BorderRadius.circular(12),
                      isExpanded: true,
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
                      onChanged: (v) =>
                          controller.role.value = v ?? EmployeeRole.tecnico,
                    );
                  }),
                  Obx(() {
                    if (controller.role.value != EmployeeRole.otro) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        spacing4,
                        TextField(
                          controller: controller.roleOtherController,
                          decoration: decoration('Indica el cargo'),
                          textInputAction: TextInputAction.next,
                        ),
                      ],
                    );
                  }),
                  spacing16,
                  const Text('Tipo de jornada (opcional)'),
                  spacing4,
                  Obx(() {
                    return DropdownButtonFormField<WorkdayType?>(
                      value: controller.workdayType.value,
                      decoration: decoration('Selecciona la jornada'),
                      borderRadius: BorderRadius.circular(12),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: null,
                          child: Text('Sin especificar'),
                        ),
                        DropdownMenuItem(
                          value: WorkdayType.completa,
                          child: Text('Jornada completa'),
                        ),
                        DropdownMenuItem(
                          value: WorkdayType.media,
                          child: Text('Media jornada'),
                        ),
                      ],
                      onChanged: (v) => controller.workdayType.value = v,
                    );
                  }),
                ],
              ),
              spacing16,

              // CARD 3: Vacaciones y AP
              BaseCard(
                title: 'Vacaciones y asuntos propios',
                children: [
                  const SizedBox(height: 8),
                  const Text('Días de vacaciones por cada 30 días trabajados'),
                  spacing4,
                  TextField(
                    controller: controller.vacationPer30Controller,
                    decoration: decoration('Ej: 2.5'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                  ),
                  spacing16,
                  const Text('Días de asuntos propios por año'),
                  spacing4,
                  TextField(
                    controller: controller.personalPerYearController,
                    decoration: decoration('Ej: 2'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ),

              spacing24,
            ],
          ),
        ),
      );
    });
  }
}