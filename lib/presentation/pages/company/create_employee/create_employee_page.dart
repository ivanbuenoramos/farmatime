import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:farmatime/presentation/pages/company/create_employee/create_employee_controller.dart';



class CreateEmployeePage extends GetView<CreateEmployeeController> {
  const CreateEmployeePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo empleado')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Obx(() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nombre del empleado'),
              const SizedBox(height: 8),
              TextField(
                controller: controller.nameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Ej: María García',
                ),
              ),
              const SizedBox(height: 20),
              const Text('Correo electrónico'),
              const SizedBox(height: 8),
              TextField(
                controller: controller.emailController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Ej: maria@empresa.com',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 30),
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
          );
        }),
      ),
    );
  }
}
