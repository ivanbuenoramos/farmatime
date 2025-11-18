import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:farmatime/presentation/presentation.dart';



class CompanyAccountPage extends StatelessWidget {
  const CompanyAccountPage({super.key});

  Widget buildSectionTitle(String title) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      );

  Widget buildInput({required String label, required TextEditingController controller, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
    );
  }

  @override
  Widget build(BuildContext context) {

    final controller = Get.find<CompanyAccountController>();

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 200,
              width: double.infinity,
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: controller.logoUrl.value.isNotEmpty
                            ? NetworkImage(controller.logoUrl.value)
                            : null,
                        child: controller.logoUrl.value.isEmpty ? const Icon(Icons.local_pharmacy_rounded, size: 40) : null,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(controller.nameController.text, style: Get.theme.textTheme.headlineMedium),
                          const SizedBox(height: 12),
                          Text(controller.brain.company.value?.email ?? '', style: Get.theme.textTheme.bodyMedium),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Card(
                    child: ListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(0),
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          leading: const Icon(Icons.local_pharmacy_rounded),
                          title: const Text('Datos de la farmacia'),
                          subtitle: Text(
                            'Editar la información de la farmacia',
                            style: Get.theme.textTheme.bodySmall,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!controller.brain.company.value!.verifiedEmail)...[
                                Icon(
                                  Icons.error_rounded,
                                  color: Colors.orange,
                                ),
                              ], 
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Get.theme.colorScheme.outline,
                              ),
                            ],
                          ),
                          onTap: controller.redirectToProfile,
                        ),
                        Divider(height: 0),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          leading: const Icon(Icons.payment),
                          title: const Text('Métodos de pago'),
                          subtitle: Text(
                            'Gestionar las tarjetas de pago',
                            style: Get.theme.textTheme.bodySmall,
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: Get.theme.colorScheme.outline,
                          ),
                          onTap: controller.redirectToPaymentMethods,
                        ),
                        Divider(height: 0),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          leading: const Icon(Icons.subscriptions_rounded),
                          title: const Text('Gestionar suscripción'),
                          subtitle: Text(
                            'Ver y modificar suscripción',
                            style: Get.theme.textTheme.bodySmall,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (controller.brain.company.value!.billingStatus != 'active' && controller.brain.company.value!.billingStatus != 'cancelled')...[
                                Icon(
                                  Icons.error_rounded,
                                  color: Colors.red,
                                ),
                              ], 
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Get.theme.colorScheme.outline,
                              ),
                            ],
                          ),
                          onTap: controller.redirectToSubscription,
                        ),
                        Divider(height: 0),
                        // if (controller.brain.company.value?.authMethod == AuthMethod.emailPassword)...[
                        //   ListTile(
                        //     contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        //     leading: const Icon(Icons.lock),
                        //     title: const Text('Cambiar contraseña'),
                        //     subtitle: Text(
                        //       'Actualizar la contraseña de la cuenta',
                        //       style: Get.theme.textTheme.bodySmall,
                        //     ),
                        //     trailing: Icon(
                        //       Icons.chevron_right_rounded,
                        //       color: Get.theme.colorScheme.outline,
                        //     ),
                        //     onTap: controller.redirectToChangePassword,
                        //   ),
                        //   Divider(height: 0),
                        // ],
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          leading: const Icon(Icons.settings_rounded),
                          title: const Text('Configuración'),
                          subtitle: Text(
                            'Ajustes de la aplicación',
                            style: Get.theme.textTheme.bodySmall,
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: Get.theme.colorScheme.outline,
                          ),
                          onTap: controller.redirectToSettings,
                        ),
                        Divider(height: 0),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          leading: const Icon(Icons.logout, color: Colors.red),
                          title: const Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
                          onTap: controller.logOut,
                        ),
                      ],
                    ),
                  ),                
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
