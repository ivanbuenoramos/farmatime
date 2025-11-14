import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'verify_email_controller.dart';

class VerifyEmailPage extends GetView<VerifyEmailController> {
  const VerifyEmailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Verificar email')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Obx(() {
            final email = controller.email ?? '—';
            final verified = controller.verified.value || controller.isEmailVerifiedFlag;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cuenta', style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(email, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 16),
                VerifiedBanner(verified: verified),
                const SizedBox(height: 24),

                Text(
                  'Te hemos enviado un correo con un enlace de verificación. Abre tu bandeja, pulsa el enlace y vuelve a la app.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: controller.isSending.value || !controller.canResend.value
                            ? null
                            : controller.sendVerificationEmail,
                        icon: controller.isSending.value
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.email_outlined),
                        label: Text(
                          controller.canResend.value
                              ? 'Enviar verificación'
                              : 'Reintentar en ${controller.secondsToResend.value}s',
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: controller.isChecking.value ? null : controller.checkNow,
                        icon: controller.isChecking.value
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.refresh),
                        label: const Text('Ya lo he verificado'),
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: controller.logOut,
                      child: const Text(
                        'Cerrar sesión',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),

                if (verified)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Continuar'),
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class VerifiedBanner extends StatelessWidget {
  const VerifiedBanner({super.key, required this.verified});
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final color = verified ? Colors.green : Colors.orange;
    final icon = verified ? Icons.check_circle : Icons.mark_email_unread_outlined;
    final text = verified ? 'Email verificado' : 'Email pendiente de verificación';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}