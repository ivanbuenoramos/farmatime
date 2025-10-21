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
      bottomNavigationBar: Obx(() {
        final currentContracted = c.brain.company.value?.contractedSeats ?? 1;
        final hasChanges = c.seats.value != (currentContracted <= 0 ? 1 : currentContracted);

        return Container(
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
                      onPressed: (!hasChanges || c.loading.value) ? null : () => c.pay(context),
                      child: c.loading.value
                          ? const SizedBox(
                              height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Continuar y pagar'),
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
          ),
        );
      }),
      body: Obx(() {
        final currentContracted = c.brain.company.value?.contractedSeats ?? 1;
        final currentSeats = (currentContracted <= 0) ? 1 : currentContracted;
        final newSeats = c.seats.value;
        final hasChanges = newSeats != currentSeats;
        final isIncrease = newSeats > currentSeats;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            BaseCard(
              title: 'Plazas de empleado',
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: c.dec,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      '$newSeats',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    IconButton(
                      onPressed: c.inc,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
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
                const Divider(height: 24),
                _kvBig(context, 'Importe mensual estimado', _fmtCents(c.monthlyCents)),
              ],
            ),

            const SizedBox(height: 12),

            BaseCard(
              title: 'Método de pago',
              children: [
                _PayChoiceTile(
                  title: 'Apple Pay / Google Pay',
                  subtitle:
                      'También podrás elegir tarjeta guardada o añadir una nueva en la hoja de pago.',
                  selected: c.method.value == SeatPayMethod.nativePay,
                  onTap: () => c.method.value = SeatPayMethod.nativePay,
                  icon: Icons.account_balance_wallet_outlined,
                ),
                const SizedBox(height: 8),
                _PayChoiceTile(
                  title: 'Tarjeta',
                  subtitle:
                      'Usa una tarjeta guardada o añade una nueva directamente en la app.',
                  selected: c.method.value == SeatPayMethod.card,
                  onTap: () => c.method.value = SeatPayMethod.card,
                  icon: Icons.credit_card,
                ),
              ],
            ),
          ],
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

class _PayChoiceTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final IconData icon;
  const _PayChoiceTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? t.colorScheme.primary : t.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
            // strokeAlign es opcional; comenta si tu SDK no lo soporta:
            // strokeAlign: BorderSide.strokeAlignOutside,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? t.colorScheme.primary : t.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: t.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle, style: t.textTheme.bodySmall),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: t.colorScheme.primary)
            else
              const Icon(Icons.circle_outlined, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}