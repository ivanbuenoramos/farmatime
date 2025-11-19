import 'package:farmatime/presentation/pages/employee/profile/employee_profile_controller.dart';
import 'package:farmatime/presentation/widgets/card/base_card.dart';
import 'package:farmatime/presentation/widgets/card/profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class EmployeeProfilePage extends StatelessWidget {
  const EmployeeProfilePage({super.key});

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

    final controller = Get.find<EmployeeProfileController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
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
                  GestureDetector(
                    onTap: controller.pickLogo,
                    child: ProfileAvatar(
                      imageUrl: controller.brain.employee.value!.photoUrl,
                      name: controller.brain.employee.value!.name,
                      size: 120,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.grey),
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(6),
                      child: Icon(Icons.edit_rounded, color: Get.theme.colorScheme.primary)
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

            BaseCard(
              title: 'Datos de la empresa',
              children: [
                const SizedBox(height: 8),
                buildInput(label: 'Nombre', controller: controller.nameController),
                const SizedBox(height: 10),
                buildInput(label: 'DNI', controller: controller.cifController),
                const SizedBox(height: 10),
                buildInput(label: 'Email', controller: controller.emailController),
              ],
            ),

          ],
        ),
      ),
    );
  }
}
