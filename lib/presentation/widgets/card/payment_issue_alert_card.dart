import 'package:farmatime/core/routes/routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PaymentIssueAlertCard extends StatelessWidget {

  final String? billingStatus;

  const PaymentIssueAlertCard({
    this.billingStatus,
    super.key
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Get.toNamed(Routes.companySubscription),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Get.theme.colorScheme.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Get.theme.colorScheme.error,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Get.theme.colorScheme.error,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                billingStatus == 'past_due'
                ? 'Tu suscripción tiene un pago pendiente. Algunas funciones pueden estar limitadas. '
                  'Por favor, actualiza tu método de pago para restaurar el acceso completo.'
                  : billingStatus == 'unpaid'
                  ? 'Tu suscripción está impagada. Algunas funciones pueden estar limitadas. '
                    'Por favor, actualiza tu método de pago para restaurar el acceso completo.'
                    : billingStatus == 'canceled'
                    ? 'Tu suscripción ha sido cancelada. Algunas funciones pueden estar limitadas. '
                      'Por favor, renueva tu suscripción para restaurar el acceso completo.'
                        : 'Tu suscripción no está activa. Algunas funciones pueden estar limitadas. '
                        'Por favor, actualiza tu método de pago para restaurar el acceso completo.',
                style: Get.textTheme.bodyMedium?.copyWith(
                  color: Get.theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}