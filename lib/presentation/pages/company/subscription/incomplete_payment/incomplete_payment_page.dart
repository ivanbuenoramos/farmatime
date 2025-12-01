import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:farmatime/presentation/pages/company/subscription/incomplete_payment/incomplete_payment_controller.dart';



class IncompletePaymentPage extends GetView<IncompletePaymentController> {
  const IncompletePaymentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pago pendiente'),
        centerTitle: false,
      ),
      body: Obx(
        () {
          final isLoading = controller.isLoading.value;
          final error = controller.errorText.value;
          final info = controller.paymentInfo.value;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  elevation: 0,
                  color: theme.colorScheme.errorContainer.withOpacity(0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: theme.colorScheme.error,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hay un pago pendiente',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'No hemos podido completar el último cobro de tu suscripción. '
                                'Tus empleados pueden seguir fichando con normalidad, '
                                'pero no podrás ver informes ni datos avanzados hasta que completes el pago.',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (info != null) _AmountCard(controller: controller),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        isLoading ? null : controller.retryPayment,
                    icon: const Icon(Icons.credit_card),
                    label: Text(
                      isLoading ? 'Procesando...' : 'Reintentar pago',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: isLoading ? null : () => Get.back(),
                  child: const Text('Volver más tarde'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.controller});

  final IncompletePaymentController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = controller.paymentInfo.value!;
    final amountLabel = controller.getAmountLabel();

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.receipt_long,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Importe pendiente',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Factura ${info.invoiceId ?? '-'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              amountLabel,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}