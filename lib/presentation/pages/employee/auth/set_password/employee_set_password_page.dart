import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:farmatime/presentation/presentation.dart';



class EmployeeSetPasswordPage extends GetView<EmployeeSetPasswordController> {
  const EmployeeSetPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('Asignar contraseña'),
        titleSpacing: 16,
      ),
      body: Obx(() => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Form(
          key: controller.formKey,
          child: Column(
            children: [
          
              TextFormField(
                controller: controller.newCtrl,
                obscureText: !controller.showNew.value,
                maxLines: 1,
                decoration: InputDecoration(
                  labelText: 'Nueva contraseña',
                  helperText: 'Mínimo 6 caracteres.',
                  suffixIcon: IconButton(
                    onPressed: () => controller.showNew.toggle(),
                    icon: Icon(
                      controller.showNew.value
                        ? Icons.visibility_off
                        : Icons.visibility,
                    ),
                  ),
                ),
                validator: controller.validateNew,
              ),
                  
              const SizedBox(height: 12),
                    
              TextFormField(
                controller: controller.confirmCtrl,
                obscureText: !controller.showConfirm.value,
                maxLines: 1,
                decoration: InputDecoration(
                  labelText: 'Confirmar nueva contraseña',
                  suffixIcon: IconButton(
                    onPressed: () => controller.showConfirm.toggle(),
                    icon: Icon(
                      controller.showConfirm.value
                        ? Icons.visibility_off
                        : Icons.visibility,
                    ),
                  ),
                ),
                validator: controller.validateConfirm,
              ),
                    
              const SizedBox(height: 24),
                    
              FilledButton(
                onPressed: controller.isLoading.value
                  ? null
                  : () => controller.submit(),
                child: controller.isLoading.value
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar cambios'),
              ),
            ],
          ),
        ),
      )),
    );
  }
}