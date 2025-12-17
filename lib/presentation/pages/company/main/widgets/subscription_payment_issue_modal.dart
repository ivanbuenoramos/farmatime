import 'package:flutter/material.dart';

class SubscriptionPaymentIssueModalContent extends StatelessWidget {
  const SubscriptionPaymentIssueModalContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          Icon(
            Icons.warning_amber_rounded,
            size: 48,
            color: theme.colorScheme.error,
          ),

          const SizedBox(height: 16),

          Text(
            'Problema con la suscripción',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'No hemos podido renovar tu suscripción. '
            'Es necesario actualizar tu método de pago o completar el pago pendiente.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).pop(); // cerrar modal

                // Get.to(
                //   () => const SubscriptionPaymentIssuePage(),
                //   binding: SubscriptionPaymentIssueBinding(),
                // );
              },
              child: const Text('Resolver ahora'),
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}