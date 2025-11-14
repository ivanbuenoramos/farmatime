import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:farmatime/presentation/pages/auth/recover_password/recover_password_controller.dart';



class ForgotPasswordPage extends GetView<ForgotPasswordController> {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    const horizontalPad = EdgeInsets.symmetric(horizontal: 16);
    const verticalGap24 = SizedBox(height: 24);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recuperar contraseña'),
      ),
      body: Obx(
        () => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Introduce el correo con el que estás registrado en Farmatime. '
                'Te enviaremos un enlace para restablecer tu contraseña.',
                style: theme.textTheme.bodyMedium,
              ),
              verticalGap24,
              TextField(
                controller: controller.emailCtrl,
                keyboardType: TextInputType.emailAddress,
                onChanged: controller.onEmailChanged,
                decoration: InputDecoration(
                  labelText: 'Correo electrónico',
                  border: const OutlineInputBorder(),
                  errorText: controller.emailError.value,
                ),
              ),
              verticalGap24,
              Padding(
                padding: horizontalPad,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: controller.canSubmit
                        ? controller.sendResetEmail
                        : null,
                    child: controller.submitting.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Enviar enlace'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}