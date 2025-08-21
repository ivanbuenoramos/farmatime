// 📄 lib/presentation/pages/company_auth/company_auth_signin_page.dart
import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:farmatime/presentation/pages/company/auth/sign_in/company_auth_sign_in_controller.dart';



class CompanyAuthSignInPage extends GetView<CompanyAuthSignInController> {
  const CompanyAuthSignInPage({super.key});

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
            Text('¡Bienvenido!', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Inicia sesión con tu cuenta de farmacia.', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 32),

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
            const SizedBox(height: 16),

            Row(
              children: [
                Checkbox(
                  value: controller.rememberMe.value,
                  onChanged: controller.setRememberMe,
                ),
                const Text('Mantener sesión iniciada')
              ],
            ),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: controller.login,
                child: const Text('Iniciar sesión'),
              ),
            ),

            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: controller.recoverPassword,
                child: const Text('¿Contraseña olvidada? Recuperarla aquí'),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: controller.redirectToSignUp,
                child: const Text('Crear cuenta'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
