import 'package:farmatime/core/routes/routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

Future<void> showEmployeeInfoLockedDialog() {
  return Get.bottomSheet(
    const EmployeeInfoLockedDialog(),
    isScrollControlled: true,
  );
}

class EmployeeInfoLockedDialog extends StatelessWidget {
  const EmployeeInfoLockedDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.error.withAlpha(20),
                ),
                child: Icon(
                  Icons.lock_clock_rounded,
                  size: 32,
                  color: theme.colorScheme.error,
                ),
              ),

              const SizedBox(height: 10),
          
              Text(
                'No puedes ver los fichajes',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium
              ),
              
              const SizedBox(height: 20),
          
              Text(
                'Hay un problema con el pago de la suscripción de tu farmacia.\n'
                'Los empleados pueden seguir fichando con normalidad, pero '
                'mientras no se regularice el pago no podrás ver los datos de fichajes.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
              ),

              const SizedBox(height: 20),
          
              // Container(
              //   width: double.infinity,
              //   padding: const EdgeInsets.all(14),
              //   decoration: BoxDecoration(
              //     borderRadius: BorderRadius.circular(12),
              //     color: theme.colorScheme.primary.withAlpha(20),
              //   ),
              //   child: Text(
              //     'En cuanto la farmacia resuelva el pago, '
              //     'recuperarás automáticamente el acceso a toda la información.',
              //     textAlign: TextAlign.left,
              //     style: theme.textTheme.bodySmall?.copyWith(
              //       color: theme.colorScheme.onSurfaceVariant,
              //     ),
              //   ),
              // ),

              const SizedBox(height: 20),
          
              FilledButton.icon(
                onPressed: () {
                  Get.back();
                  Get.toNamed(Routes.companySubscription);
                },
                icon: const Icon(Icons.credit_card_outlined),
                label: const Text('Revisar pagos'),
              ),
              
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}