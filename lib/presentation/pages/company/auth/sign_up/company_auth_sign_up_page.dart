import 'package:farmatime/presentation/widgets/buttons/block_button.dart';
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
          icon: const Icon(Icons.arrow_back_rounded, size: 30, color: Colors.black),
          onPressed: () => Get.back(),
        ),
      ),
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height - kToolbarHeight - MediaQuery.of(context).padding.top - 48,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'farmatime',
                style: Get.theme.textTheme.headlineLarge?.copyWith(
                  color: Get.theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 26,
                  fontStyle:  FontStyle.italic,
                ),
              ),
              
              const SizedBox(height: 20),
              
              Text('Crear cuenta', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              
              const SizedBox(height: 10),
          
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
          
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: BlockButton(
                  onPressed: controller.register,
                  label: 'Crear cuenta',
                ),
              ),
          
              Spacer(),
              Column(
                  children: [
                    Text(
                      'Ya tienes cuenta?',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Get.theme.colorScheme.secondary,
                      ),
                    ),
                    Center(
                      child: TextButton(
                        onPressed: Get.back,
                        child: const Text('Iniciar sesión'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
