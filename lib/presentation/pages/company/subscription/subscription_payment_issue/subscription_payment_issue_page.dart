import 'package:farmatime/presentation/widgets/card/base_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'subscription_payment_issue_controller.dart';

class SubscriptionPaymentIssuePage extends GetView<SubscriptionPaymentIssueController> {
  const SubscriptionPaymentIssuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Problema con el pago')),
      body: Obx(() {
        if (controller.loading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            BaseCard(
              title: 'Pago fallido',
              children: [
                Text(
                  'No hemos podido renovar tu suscripción mensual. '
                  'Para mantener el servicio activo, por favor actualiza tu método de pago '
                  'o intenta realizar el pago nuevamente.',
                  style: Get.textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => controller.addPaymentMethod(context),
              icon: const Icon(Icons.credit_card),
              label: const Text('Añadir o actualizar tarjeta'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => controller.retryLastInvoicePayment(context),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar pago'),
            ),
          ],
        );
      }),
    );
  }
}