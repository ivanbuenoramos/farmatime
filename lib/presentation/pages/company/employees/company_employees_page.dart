// 📄 lib/presentation/pages/company/employees/company_employees_page.dart
import 'package:farmatime/presentation/widgets/card/base_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:farmatime/presentation/pages/company/employees/company_employees_controller.dart';

class CompanyEmployeesPage extends StatelessWidget {
  const CompanyEmployeesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final CompanyEmployeesController controller = Get.find<CompanyEmployeesController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de empleados'),
      ),
      floatingActionButton: FloatingActionButton(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
        onPressed: controller.reditectToCreateEmployee,
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        final employees = controller.employees;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: BaseCard(
            title: 'Empleados',
            children: [
              GridView.builder(
                itemCount: employees.length,
                shrinkWrap: true, // 👉 evita ocupar todo el espacio disponible
                physics: const NeverScrollableScrollPhysics(), // 👉 desactiva scroll independiente
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.85,
                ),
                itemBuilder: (context, index) {
                  final employee = employees[index];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => controller.reditectToEmployeeDetail(employee),
                      borderRadius: BorderRadius.circular(8),
                      child: Ink(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Get.theme.colorScheme.surface,
                          border: Border.all(color: Get.theme.colorScheme.outline),
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
                            ),
                            const SizedBox(height: 4),
                            Text(
                              employee.position ?? 'Empleado',
                              style: Get.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              employee.email ?? 'Jornada completa',
                              style: Get.textTheme.bodySmall?.copyWith(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      }),
    );
  }
}
