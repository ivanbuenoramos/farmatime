import 'package:farmatime/presentation/widgets/card/base_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:farmatime/presentation/pages/company/employees/company_employees_controller.dart';

class CompanyEmployeesPage extends StatelessWidget {
  const CompanyEmployeesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CompanyEmployeesController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de empleados'),
      ),
      floatingActionButton:FloatingActionButton(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
            ),
            onPressed: controller.onAddEmployeePressed,
            child: const Icon(Icons.add),
          ),
      body: Obx(() {
        final employees = controller.employees;
        final seats = controller.contractedSeats.value;

        // total de tarjetas = max(empleados existentes, plazas contratadas)
        final totalCards = (seats > employees.length) ? seats : employees.length;

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: BaseCard(
              title:
                  'Empleados · ${employees.length}/$seats', // indicador breve
              children: [
                if (controller.isLoading.value)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(),
                  ),
                GridView.builder(
                  itemCount: totalCards,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.85,
                  ),
                  itemBuilder: (context, index) {
                    final isRealEmployee = index < employees.length;

                    if (isRealEmployee) {
                      final employee = employees[index];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () =>
                              controller.reditectToEmployeeDetail(employee),
                          borderRadius: BorderRadius.circular(8),
                          child: Ink(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Get.theme.colorScheme.surface,
                              border: Border.all(
                                  color: Get.theme.colorScheme.outline),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircleAvatar(
                                  radius: 40,
                                  backgroundImage: NetworkImage(
                                    'https://randomuser.me/api/portraits/men/32.jpg',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  employee.name,
                                  style: Get.textTheme.bodyLarge?.copyWith(
                                    color: Get.theme.colorScheme.secondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  employee.position ?? 'Empleado',
                                  style: Get.textTheme.bodyMedium
                                      ?.copyWith(color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  employee.email ?? 'Jornada completa',
                                  style: Get.textTheme.bodySmall?.copyWith(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    // Tarjeta vacía (hueco libre contratado)
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: controller.onAddEmployeePressed,
                        borderRadius: BorderRadius.circular(8),
                        child: DottedSlotCard(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

/// Tarjeta visual para un hueco contratado libre
class DottedSlotCard extends StatelessWidget {
  const DottedSlotCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Ink(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.surface,
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.7),
          style: BorderStyle.solid,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_add_alt_1,
                size: 36, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              'Añadir empleado',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Hueco libre',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}