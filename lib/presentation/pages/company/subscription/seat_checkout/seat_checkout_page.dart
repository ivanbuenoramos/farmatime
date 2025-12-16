import 'package:farmatime/presentation/widgets/card/base_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'seat_checkout_controller.dart';

class SeatCheckoutPage extends StatelessWidget {
  const SeatCheckoutPage({super.key});

  String _fmtCents(int cents) {
    final fmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');
    return fmt.format(cents / 100).replaceAll(' ', '');
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<SeatCheckoutController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Actualizar plazas')),
      bottomNavigationBar:Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Get.theme.colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Get.theme.colorScheme.outline,
              ),
            ),
          ),
          child: SafeArea(
            child: Obx(() {
              final currentContracted = c.brain.company.value?.contractedSeats ?? 1;
              final currentSeats = (currentContracted <= 0) ? 1 : currentContracted;
              final newSeats = c.seats.value;
              final hasChanges = newSeats != currentSeats;
              final isIncrease = newSeats > currentSeats;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => c.onContinue(),
                      child: const Text('Continuar'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _helperText(hasChanges: hasChanges, isIncrease: isIncrease),
                    style: Get.textTheme.bodySmall?.copyWith(
                      color: isIncrease
                          ? Get.theme.colorScheme.primary
                          : (hasChanges ? Get.theme.colorScheme.secondary : Colors.grey),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }),
          )
      ),
      body: Obx(() {
        final currentContracted = c.brain.company.value?.contractedSeats ?? 1;
        final currentSeats = (currentContracted <= 0) ? 1 : currentContracted;
        final newSeats = c.seats.value;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            children: [
              BaseCard(
                title: 'Plazas de empleado',
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        InkWell(
                          onTap: c.seats.value <= 1 ? null : c.dec,
                          borderRadius: BorderRadius.circular(24),
                          child: Ink(
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c.seats.value <= 1
                                  ? Get.theme.colorScheme.tertiary.withAlpha(40)
                                  : Get.theme.colorScheme.primary.withAlpha(40),
                            ),
                            child: Icon(
                              Icons.remove_rounded,
                              color: c.seats.value <= 1
                                ? Get.theme.colorScheme.tertiary
                                : Get.theme.colorScheme.primary
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '$newSeats',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontSize: 48,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        InkWell(
                          onTap: c.seats.value >= 100 ? null : c.inc,
                          borderRadius: BorderRadius.circular(24),
                          child: Ink(
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c.seats.value >= 100
                                  ? Get.theme.colorScheme.tertiary.withAlpha(40)
                                  : Get.theme.colorScheme.primary.withAlpha(40),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              color: c.seats.value >= 100
                                ? Get.theme.colorScheme.tertiary
                                : Get.theme.colorScheme.primary
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'La primera plaza es gratuita. A partir de la segunda: 1,00 € / mes por plaza.',
                    style: Get.theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
          
              const SizedBox(height: 12),
          
              BaseCard(
                title: 'Resumen',
                children: [
                  _kv(context, 'Tipo de suscripción', 'Mensual'),
                  const SizedBox(height: 8),
                  _kv(context, 'Actualmente contratadas', '$currentSeats'),
                  const SizedBox(height: 8),
                  _kv(context, 'Nueva cantidad', '$newSeats'),
                  // const Divider(height: 24),
                  // _kvBig(context, 'Importe mensual estimado', _fmtCents(c.pr)),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }

  String _helperText({required bool hasChanges, required bool isIncrease}) {
    if (!hasChanges) return 'No has realizado cambios.';
    return isIncrease
        ? 'Se abrirá la hoja de pago para confirmar el cargo.'
        : 'Al reducir plazas no se realizará un cargo ahora.';
  }

  Widget _kv(BuildContext ctx, String k, String v) {
    final t = Theme.of(ctx);
    return Row(
      children: [
        Expanded(child: Text(k, style: t.textTheme.bodyMedium)),
        Text(
          v,
          style: t.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: t.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _kvBig(BuildContext ctx, String k, String v) {
    final t = Theme.of(ctx);
    return Row(
      children: [
        Expanded(child: Text(k, style: t.textTheme.headlineSmall)),
        Text(
          v,
          style: t.textTheme.headlineSmall?.copyWith(color: t.colorScheme.primary),
        ),
      ],
    );
  }
}