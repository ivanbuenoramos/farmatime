import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'select_employee_to_remove_controller.dart';



class SelectEmployeeToRemovePage extends GetView<SelectEmployeeToRemoveController> {
  const SelectEmployeeToRemovePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar empleados'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Get.back(result: null),
        ),
      ),
      body: Obx(() {
        if (controller.loading.value && controller.employees.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.employees.isEmpty) {
          return Center(
            child: Text(
              controller.error.value.isNotEmpty
                  ? controller.error.value
                  : 'No hay empleados activos.',
              style: theme.textTheme.bodyMedium,
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Debes seleccionar ${controller.mustRemove} empleado(s) que perderán el acceso.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: controller.employees.length,
                itemBuilder: (_, i) {
                  final emp = controller.employees[i];
                  final id = emp.uid;
                  final selected = controller.selectedIds.contains(id);

                  return CheckboxListTile(
                    value: selected,
                    onChanged: (_) => controller.toggleSelect(id),
                    title: Text(emp.name),
                    subtitle: Text(emp.email),
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Obx(() {
                  return FilledButton(
                    onPressed: controller.loading.value
                        ? null
                        : controller.isValid
                            ? controller.confirm
                            : null,
                    child: controller.loading.value
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Confirmar'),
                  );
                }),
              ),
            ),
          ],
        );
      }),
    );
  }
}