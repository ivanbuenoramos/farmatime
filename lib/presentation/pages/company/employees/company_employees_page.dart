import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/presentation/pages/company/employees/widgets/info_locked_dialog.dart';
import 'package:farmatime/presentation/widgets/card/base_card.dart';
import 'package:farmatime/presentation/widgets/card/payment_issue_alert_card.dart';
import 'package:farmatime/presentation/widgets/card/profile_avatar.dart';
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
        titleSpacing: 16,
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

        final totalCards = (seats > employees.length) ? seats : employees.length;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            children: [
              if (controller.brain.company.value!.billingStatus != 'active' && controller.brain.company.value!.billingStatus != 'none') ... [
                PaymentIssueAlertCard(
                  billingStatus: controller.brain.company.value!.billingStatus,
                ),
                const SizedBox(height: 12),
              ],
              BaseCard(
                title: 'Empleados · ${employees.length}/$seats',
                children: [
              
                  if (controller.isLoading.value)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: LinearProgressIndicator(),
                    ),

                  ListView.separated(
                    shrinkWrap: true,
                    itemCount: totalCards,
                    physics: const NeverScrollableScrollPhysics(),
                    separatorBuilder: (_, __) => const SizedBox(height: 5),
                    itemBuilder: (context, index) {
              
                      final isRealEmployee = index < employees.length;
              
                      if (isRealEmployee) {
                        final employee = employees[index];
                        return Opacity(
                          opacity: (employee.accountStatus == EmployeeAccountStatus.active) ? 1.0 : 0.6,
                          child: InkWell(
                            onTap: () {
                              if (employee.accountStatus == EmployeeAccountStatus.active) {
                                controller.reditectToEmployeeDetail(employee);
                              } else {
                                showEmployeeInfoLockedDialog();
                              }
                            },
                            child: Ink(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Get.theme.colorScheme.surface,
                                border: Border.all(
                                  color: Get.theme.colorScheme.outline.withOpacity(0.7),
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Row(
                                children: [
                                  ProfileAvatar(
                                    imageUrl: employee.photoUrl,
                                    name: employee.name,
                                    size: 45,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          employee.name,
                                          style: Get.textTheme.bodyMedium?.copyWith(
                                            color: Get.theme.colorScheme.secondary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            // Text(
                                            //   employee.position ?? 'Empleado',
                                            //   style: Get.textTheme.bodySmall
                                            // ),
                                            Text(
                                              employee.accountStatus?.name ?? 'Estado desconocido',
                                              style: Get.textTheme.bodySmall
                                            ),
                                            if (employee.workdayType != null) ...[
                                              const SizedBox(width: 10),
                                              Text(
                                                employee.workdayType == WorkdayType.completa
                                                    ? 'Jornada completa'
                                                    : employee.workdayType == WorkdayType.media
                                                        ? 'Parcial'
                                                        : 'Sin definir',
                                                style: Get.textTheme.bodySmall?.copyWith(
                                                  color: Get.theme.colorScheme.primary,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Icon(Icons.chevron_right_rounded, color: Get.theme.colorScheme.outline, size: 32),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      // Tarjeta vacía (hueco libre contratado)
                      return DottedSlotCard(
                        onTap: controller.onAddEmployeePressed,
                        enabled: controller.brain.company.value!.billingStatus == 'active' || controller.brain.company.value!.billingStatus == 'none',
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// Tarjeta visual para un hueco contratado libre
class DottedSlotCard extends StatelessWidget {

  final VoidCallback? onTap;
  final bool enabled;

  const DottedSlotCard({
    this.onTap,
    this.enabled = true,
    super.key
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: enabled ? 1.0 : 0.6,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? onTap : null,
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: theme.colorScheme.primary.withAlpha(20),
            border: Border.all(
              color: theme.colorScheme.outline,
              style: BorderStyle.solid,
            ),
          ),
          child: Center(
            child: Row(
              children: [
                Container(
                  height: 48,
                  width: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary.withOpacity(0.1),
                  ),
                  child: Icon(
                    Icons.person_add_alt_1,
                    size: 20, 
                    color: theme.colorScheme.primary
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}