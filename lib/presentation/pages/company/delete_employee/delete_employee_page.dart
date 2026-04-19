import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:farmatime/data/models/employee_model.dart';
import 'delete_employee_controller.dart';

class DeleteEmployeePage extends GetView<DeleteEmployeeController> {
  const DeleteEmployeePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing8 = const SizedBox(height: 8);
    final spacing16 = const SizedBox(height: 16);
    final spacing24 = const SizedBox(height: 24);

    final EmployeeModel employee = controller.employee.value!;

    InputDecoration confirmationDecoration = InputDecoration(
      labelText: 'Confirma el nombre del empleado',
      hintText: employee.name,
      border: const OutlineInputBorder(),
    );

    return GetBuilder<DeleteEmployeeController>(
      builder: (_) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: theme.colorScheme.error,
            title: const Text('Eliminar empleado'),
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outline
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                ),
              ],
            ),
            child: SafeArea(
              child: Obx(
                () => FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  ),
                  onPressed: (!controller.isNameCorrect ||
                          controller.isDeleting.value)
                      ? null
                      : controller.deleteEmployee,
                  child: controller.isDeleting.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Eliminar definitivamente'),
                ),
              ),
            ),
          ),
          body: GetBuilder<DeleteEmployeeController>(
            builder: (_) {
          
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _EmployeeAvatar(employee: employee),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                employee.name,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              spacing8,
                              Text(
                                employee.email,
                                style: theme.textTheme.bodyMedium
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    spacing24,
                
                    // Aviso fuerte
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.warning_rounded,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Esta acción es irreversible.',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    spacing24,
                    Text(
                      'Se eliminará la cuenta de este empleado y perderá el acceso a la app. '
                      'Los datos históricos de fichajes se conservarán para cumplir con la normativa, '
                      'pero el empleado ya no podrá iniciar sesión.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    spacing16,
                    Text(
                      'Para confirmar, escribe exactamente el nombre del empleado:',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    spacing24,
                
                    TextField(
                      controller: controller.confirmationController,
                      autofocus: true,
                      onChanged: controller.onConfirmationChanged,
                      decoration: confirmationDecoration.copyWith(
                        errorText: controller.confirmationController.text.isEmpty
                            ? null
                            : (controller.isNameCorrect ? null : 'El nombre no coincide'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      }
    );
  }
}

class _EmployeeAvatar extends StatelessWidget {
  final EmployeeModel employee;

  const _EmployeeAvatar({required this.employee});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPhoto =
        employee.photoUrl != null && employee.photoUrl!.trim().isNotEmpty;

    String initialsFromName(String name) {
      final parts = name.trim().split(' ');
      if (parts.isEmpty) return '';
      if (parts.length == 1) return parts.first.characters.first.toUpperCase();
      return (parts.first.characters.first +
              parts.last.characters.first)
          .toUpperCase();
    }

    return CircleAvatar(
      radius: 28,
      backgroundColor: theme.colorScheme.primaryContainer,
      backgroundImage: hasPhoto ? NetworkImage(employee.photoUrl!) : null,
      child: !hasPhoto
          ? Text(
              initialsFromName(employee.name),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }
}