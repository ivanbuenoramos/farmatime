import 'package:farmatime/presentation/pages/auth/change_password/change_password_controller.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';



class ChangePasswordPage extends GetView<ChangePasswordController> {
  const ChangePasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cambiar contraseña'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Form(
            key: controller.formKey,
            child: Column(
              children: [
                Text(
                  'Por seguridad, primero reautenticaremos tu cuenta con tu contraseña actual.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
          
                // Actual
                Obx(() => TextFormField(
                      controller: controller.currentCtrl,
                      obscureText: !controller.showCurrent.value,
                      decoration: InputDecoration(
                        labelText: 'Contraseña actual',
                        suffixIcon: IconButton(
                          onPressed: () => controller.showCurrent.toggle(),
                          icon: Icon(
                            controller.showCurrent.value
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                      validator: controller.validateCurrent,
                    )),
                const SizedBox(height: 12),
          
                // Nueva
                Obx(() => TextFormField(
                  controller: controller.newCtrl,
                  obscureText: !controller.showNew.value,
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
                )),
          
                const SizedBox(height: 12),
          
                Obx(() => TextFormField(
                  controller: controller.confirmCtrl,
                  obscureText: !controller.showConfirm.value,
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
                )),
          
                const SizedBox(height: 24),
          
                Obx(() => FilledButton(
                      onPressed: controller.isLoading.value
                          ? null
                          : () => controller.submit(),
                      child: controller.isLoading.value
                          ? const SizedBox(
                              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Guardar cambios'),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}