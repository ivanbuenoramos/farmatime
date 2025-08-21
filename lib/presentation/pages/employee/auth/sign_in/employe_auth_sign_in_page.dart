// 📄 lib/presentation/pages/employee_auth/employee_auth_signin_page.dart
import 'package:farmatime/presentation/widgets/buttons/block_button.dart';
import 'package:farmatime/presentation/widgets/custom_text_input.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:farmatime/presentation/pages/employee/auth/sign_in/employe_auth_sign_in_controller.dart';



class EmployeeAuthSignInPage extends GetView<EmployeeAuthSignInController> {
  const EmployeeAuthSignInPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 30, color: Colors.black),
          onPressed: () => Get.back(),
        ),
      ),
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            Text(
              'farmatime',
              style: Get.theme.textTheme.headlineLarge?.copyWith(
                color: Get.theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 20,
                fontStyle:  FontStyle.italic,
              ),
            ),
            
            const SizedBox(height: 20),
            
            Text('¡Bienvenido!', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            
            const SizedBox(height: 10),
            
            Text('Nos alegramos de verte de nuevo.', style: theme.textTheme.bodyMedium),
            
            const SizedBox(height: 32),

            CustomTextInput(
              controller: controller.emailController,
              hintText: 'Correo electrónico',
              keyboardType: TextInputType.emailAddress,
            ),
            
            const SizedBox(height: 16),
            
            CustomTextInput(
              controller: controller.passwordController,
              hintText: 'Contraseña',
              obscureText: true,
            ),
            
            const SizedBox(height: 25),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: BlockButton(
                onPressed: controller.login,
                label: 'INICIAR SESIÓN',
              ),
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '¿Contraseña olvidada?',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Get.theme.colorScheme.secondary,
                  ),
                ),
                TextButton(
                  onPressed: controller.recoverPassword,
                  child: const Text(
                    'Recuperarla aquí',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
