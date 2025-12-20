import 'package:farmatime/core/routes/routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PaymentIssueAlertCard extends StatelessWidget {

  final String? billingStatus;
  final Color? color;
  final Function()? onTap;

  const PaymentIssueAlertCard({
    this.billingStatus,
    this.color,
    this.onTap,
    super.key
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () => Get.toNamed(Routes.companySubscription),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color != null 
            ? color!.withOpacity(0.1)
            : billingStatus == 'active' || billingStatus == 'none'
              ? Get.theme.colorScheme.primary.withOpacity(0.1)
              : Get.theme.colorScheme.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color != null 
              ? color!
              : billingStatus == 'active' || billingStatus == 'none'
                ? Get.theme.colorScheme.primary
                : Get.theme.colorScheme.error,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                if (billingStatus != 'none')...[
                  Icon(
                    billingStatus == 'active' 
                      ? Icons.check_circle_rounded
                      : Icons.warning_amber_rounded,
                    color: billingStatus == 'active' || billingStatus == 'none'
                      ? Get.theme.colorScheme.primary
                      : Get.theme.colorScheme.error,
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    billingStatus == 'active' 
                      ? 'Tu suscripción está activa.'
                        : billingStatus == 'past_due'
                        ? 'Tu suscripción tiene un pago pendiente. Algunas funciones pueden estar limitadas. '
                          'Por favor, actualiza tu método de pago para restaurar el acceso completo.'
                          : billingStatus == 'unpaid'
                          ? 'Tu suscripción está impagada. Algunas funciones pueden estar limitadas. '
                            'Por favor, actualiza tu método de pago para restaurar el acceso completo.'
                            : billingStatus == 'canceled'
                            ? 'Tu suscripción ha sido cancelada. Algunas funciones pueden estar limitadas. '
                              'Por favor, renueva tu suscripción para restaurar el acceso completo.'
                                : billingStatus == 'none'
                                ? 'Puedes contratar más asientos para tu equipo y ampliar las funcionalidades.'
                                    : 'Tu suscripción no está activa. Algunas funciones pueden estar limitadas. '
                                    'Por favor, actualiza tu método de pago para restaurar el acceso completo.',
                    style: Get.textTheme.bodyMedium?.copyWith(
                      color: color != null 
                        ? color!
                        : billingStatus == 'active' || billingStatus == 'none'
                          ? Get.theme.colorScheme.primary 
                          : Get.theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: color != null 
                  ? color!
                  : billingStatus == 'active' || billingStatus == 'none'
                    ? Get.theme.colorScheme.primary
                    : Get.theme.colorScheme.error,
              ),
              onPressed: onTap ?? () {
                if (billingStatus == 'canceled') {
                  Get.toNamed(Routes.companySubscription);
                  return;
                } else if (billingStatus == 'past_due' || billingStatus == 'unpaid') {
                  Get.toNamed(Routes.companySubscriptionPaymentIssue);
                  return;
                }
              },
              child: Text(
                  billingStatus == 'active'
                  ? 'Modificar suscripción'
                  : billingStatus == 'past_due'
                  ? 'Revisar pago pendiente'
                    : billingStatus == 'unpaid'
                    ? 'Actualizar método de pago'
                      : billingStatus == 'canceled'
                      ? 'Renovar suscripción'
                      : billingStatus == 'none'
                        ? 'Contratar más asientos'
                        : '$billingStatus',
              ),
            ),
          ],
        ),
      ),
    );
  }
}