import 'package:farmatime/presentation/pages/company/profile/company_profile_controller.dart';
import 'package:farmatime/presentation/widgets/card/base_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CompanyProfilePage extends StatelessWidget {
  const CompanyProfilePage({super.key});

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

    final controller = Get.find<CompanyProfileController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil de farmacia'),
        actions: [
          //pupUp menu
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                controller.logOut();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'logout',
                child: Text('Cerrar sesión'),
              ),
            ]
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Obx(() {
              return Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: controller.logoUrl.value.isNotEmpty
                        ? NetworkImage(controller.logoUrl.value)
                        : null,
                    child: controller.logoUrl.value.isEmpty ? const Icon(Icons.local_pharmacy, size: 48) : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: IconButton(
                      onPressed: controller.pickLogo,
                      icon: const Icon(Icons.edit, color: Colors.blue),
                    ),
                  ),
                  if (controller.isUploadingLogo.value)
                    const Positioned.fill(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              );
            }),
            const SizedBox(height: 12),
            Text(controller.nameController.text, style: Get.theme.textTheme.headlineMedium),
            const SizedBox(height: 16),

            /// Dirección
            BaseCard(
              title: 'Dirección de la empresa',
              description: 'Asegúrate de que la dirección es correcta para que los empleados puedan encontrar tu farmacia.',
              children: [
                buildInput(label: 'Dirección', controller: controller.addressController),
                Row(
                  children: [
                    Expanded(child: buildInput(label: 'Ciudad', controller: controller.cityController)),
                    const SizedBox(width: 12),
                    Expanded(child: buildInput(label: 'Código Postal', controller: controller.postalCodeController)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: buildInput(label: 'Provincia', controller: controller.provinceController)),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: TextField(
                        enabled: false,
                        decoration: InputDecoration(labelText: 'País', hintText: 'España'),
                      ),
                    ),
                  ],
                ),

              ],
            ),
            
            const SizedBox(height: 15),

            /// Datos empresa
            BaseCard(
              title: 'Datos de la empresa',
              children: [
                buildInput(label: 'Nombre de la empresa', controller: controller.nameController),
                buildInput(label: 'CIF', controller: controller.cifController),
                buildInput(label: 'Email', controller: controller.emailController),
                Row(
                  children: [
                    Expanded(
                      child: buildInput(
                        label: 'Teléfono',
                        controller: controller.phoneController,
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: controller.saveChanges,
                      child: const Text('Cambiar'),
                    ),
                  ],
                ),
              ],
            ),

          ],
        ),
      ),
    );
  }
}
