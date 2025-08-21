import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:farmatime/presentation/pages/company/auth/sign_up/company_auth_sign_up_controller.dart';



class CompanyAuthSignUpPage extends GetView<CompanyAuthSignUpController> {
  const CompanyAuthSignUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('farmatime', style: theme.textTheme.titleLarge?.copyWith(color: Colors.blue, fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            Text('Crear cuenta', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Registra tu farmacia para empezar a gestionar empleados.', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 32),

            TextField(
              controller: controller.nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la farmacia',
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: controller.emailController,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            TextField(
              controller: controller.passwordController,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: controller.register,
                child: const Text('Crear cuenta'),
              ),
            ),

            const SizedBox(height: 32),
            Center(
              child: TextButton(
                onPressed: () => Get.back(),
                child: const Text('¿Ya tienes cuenta? Inicia sesión aquí'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
