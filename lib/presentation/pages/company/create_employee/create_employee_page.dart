// lib/presentation/pages/company/create_employee/create_employee_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'create_employee_controller.dart';
import 'package:farmatime/data/models/employee_model.dart';

class CreateEmployeePage extends GetView<CreateEmployeeController> {
  const CreateEmployeePage({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing8 = const SizedBox(height: 8);
    final spacing16 = const SizedBox(height: 16);
    final spacing20 = const SizedBox(height: 20);
    final spacing30 = const SizedBox(height: 30);

    InputDecoration decoration(String hint) => InputDecoration(
          border: const OutlineInputBorder(),
          hintText: hint,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo empleado')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Obx(() {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nombre
                const Text('Nombre del empleado'),
                spacing8,
                TextField(
                  controller: controller.nameController,
                  decoration: decoration('Ej: María García'),
                  textInputAction: TextInputAction.next,
                ),
                spacing20,

                // Email
                const Text('Correo electrónico'),
                spacing8,
                TextField(
                  controller: controller.emailController,
                  decoration: decoration('Ej: maria@empresa.com'),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                spacing20,

                // Precio por hora
                const Text('Precio por hora (€)'),
                spacing8,
                TextField(
                  controller: controller.hourlyRateController,
                  decoration: decoration('Ej: 12,50'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                ),
                spacing16,

                // Cargo
                const Text('Cargo'),
                spacing8,
                DropdownButtonFormField<EmployeeRole>(
                  value: controller.role.value,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: EmployeeRole.tecnico, child: Text('Técnico de farmacia')),
                    DropdownMenuItem(value: EmployeeRole.auxiliar, child: Text('Auxiliar de farmacia')),
                    DropdownMenuItem(value: EmployeeRole.farmaceutico, child: Text('Farmacéutico')),
                    DropdownMenuItem(value: EmployeeRole.otro, child: Text('Otro (especificar)')),
                  ],
                  onChanged: (v) => controller.role.value = v ?? EmployeeRole.tecnico,
                ),
                if (controller.role.value == EmployeeRole.otro) ...[
                  spacing8,
                  TextField(
                    controller: controller.roleOtherController,
                    decoration: decoration('Indica el cargo'),
                    textInputAction: TextInputAction.next,
                  ),
                ],
                spacing16,

                // Tipo de jornada (opcional)
                const Text('Tipo de jornada (opcional)'),
                spacing8,
                DropdownButtonFormField<WorkdayType?>(
                  value: controller.workdayType.value,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Sin especificar')),
                    DropdownMenuItem(value: WorkdayType.completa, child: Text('Jornada completa')),
                    DropdownMenuItem(value: WorkdayType.media, child: Text('Media jornada')),
                  ],
                  onChanged: (v) => controller.workdayType.value = v,
                ),
                spacing16,

                // Vacaciones por cada 30 días trabajados
                const Text('Días de vacaciones por cada 30 días trabajados'),
                spacing8,
                TextField(
                  controller: controller.vacationPer30Controller,
                  decoration: decoration('Ej: 2.5'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                ),
                spacing16,

                // Asuntos propios por año
                const Text('Días de asuntos propios por año'),
                spacing8,
                TextField(
                  controller: controller.personalPerYearController,
                  decoration: decoration('Ej: 2'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                spacing30,

                // Botón crear
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: controller.isLoading.value ? null : controller.createEmployee,
                    child: controller.isLoading.value
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Crear empleado'),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}