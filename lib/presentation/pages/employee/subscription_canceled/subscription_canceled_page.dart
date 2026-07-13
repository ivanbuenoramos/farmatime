import 'package:farmatime/presentation/pages/employee/subscription_canceled/subscription_canceled_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class EmployeeSubscriptionCanceledPage extends StatelessWidget {
  const EmployeeSubscriptionCanceledPage({super.key});

  @override
  Widget build(BuildContext context) {

    final controller = Get.find<EmployeeSubscriptionCanceledController>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  Text(
                    'farmatime', 
                    style: Get.theme.textTheme.headlineLarge?.copyWith(
                      color: Get.theme.colorScheme.primary,
                      fontSize: 32, 
                      letterSpacing: -0.5,
                      fontStyle: FontStyle.italic
                    )
                  ),

                  const SizedBox(height: 32),

                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withAlpha(12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.block_rounded,
                      size: 48,
                      color: theme.colorScheme.error,
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Tu acceso está deshabilitado',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'De momento no puedes acceder a la app. Por favor, '
                    'contacta con el personal administrativo de tu farmacia '
                    'para que reactive tu cuenta.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                  ),

                  const SizedBox(height: 24),

                  Card(
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_rounded,
                                size: 26,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Qué significa esto',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.secondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _Bullet(
                            text: 'Tu cuenta de empleado sigue existiendo, pero está deshabilitada.',
                          ),
                          const SizedBox(height: 4),
                          _Bullet(
                            text: 'No se registrarán nuevos fichajes hasta que se reactive tu acceso.',
                          ),
                          const SizedBox(height: 4),
                          _Bullet(
                            text: 'Habla con el personal administrativo de tu farmacia para resolverlo.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Si crees que se trata de un error, ponte en contacto con tu responsable.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                  ),

                  const SizedBox(height: 32),
                  
                  TextButton(
                    onPressed: () {
                      controller.logOut();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    child: Text(
                      'Cerrar sesión',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '•  ',
          style: theme.textTheme.bodyMedium,
        ),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.secondary,
            ),
          ),
        ),
      ],
    );
  }
}