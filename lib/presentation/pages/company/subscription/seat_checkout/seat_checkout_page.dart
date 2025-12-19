// seat_checkout_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'seat_checkout_controller.dart';
import 'package:farmatime/presentation/widgets/card/base_card.dart';

class SeatCheckoutPage extends StatelessWidget {
  const SeatCheckoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SeatCheckoutController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Modificar suscripción')),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Get.theme.colorScheme.surface,
          border: Border(top: BorderSide(color: Get.theme.colorScheme.outline)),
        ),
        child: SafeArea(
          child: Obx(() {
            final currentContracted = controller.brain.company.value?.contractedSeats ?? 1;
            final currentSeats = (currentContracted <= 0) ? 1 : currentContracted;
            final newSeats = controller.seats.value;
            final hasChanges = newSeats != currentSeats;
            final isIncrease = newSeats > currentSeats;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: controller.processing.value ? null : controller.onContinue,
                    child: controller.processing.value
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Continuar'),
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
      ),
      body: Obx(() {
        final currentContracted = controller.brain.company.value?.contractedSeats ?? 1;
        final currentSeats = (currentContracted <= 0) ? 1 : currentContracted;
        final newSeats = controller.seats.value;

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
                          onTap: controller.seats.value <= 1 ? null : controller.dec,
                          borderRadius: BorderRadius.circular(24),
                          child: Ink(
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: controller.seats.value <= 1
                                  ? Get.theme.colorScheme.tertiary.withAlpha(40)
                                  : Get.theme.colorScheme.primary.withAlpha(40),
                            ),
                            child: Icon(
                              Icons.remove_rounded,
                              color: controller.seats.value <= 1
                                  ? Get.theme.colorScheme.tertiary
                                  : Get.theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '$newSeats',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 48),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        InkWell(
                          onTap: controller.seats.value >= 100 ? null : controller.inc,
                          borderRadius: BorderRadius.circular(24),
                          child: Ink(
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: controller.seats.value >= 100
                                  ? Get.theme.colorScheme.tertiary.withAlpha(40)
                                  : Get.theme.colorScheme.primary.withAlpha(40),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              color: controller.seats.value >= 100
                                  ? Get.theme.colorScheme.tertiary
                                  : Get.theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'La primera plaza es gratuita. A partir de la segunda: 1,00 € / mes por plaza + IVA.',
                    style: Get.theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              BaseCard(
                title: 'Resumen',
                children: [
                  // ✅ nota de estimación
                  Text(
                    'Importes estimados. El cobro final puede variar ligeramente por prorrateo y redondeos.',
                    style: Get.textTheme.bodySmall?.copyWith(
                      color: Get.theme.colorScheme.onSurface.withAlpha(150),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Obx(() {
                    final cur = controller.currency.value;

                    final nowSub = controller.nowSubtotalCents.value;
                    final nowTax = controller.nowTaxCents.value;
                    final nowTot = controller.nowTotalCents.value;

                    final nextSub = controller.nextSubtotalCents.value;
                    final nextTax = controller.nextTaxCents.value;
                    final nextTot = controller.nextTotalCents.value;

                    Widget moneyOrDash(int? cents, {bool strong = false}) {
                      if (cents == null) return Text('—', style: Get.textTheme.bodyMedium);
                      return Text(
                        _fmtMoney(cents, cur),
                        style: (strong ? Get.textTheme.bodyLarge : Get.textTheme.bodyMedium)?.copyWith(
                          fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                          color: Get.theme.colorScheme.primary,
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(context, 'Pagarás hoy'),
                        _kvCustom(context, 'Subtotal', moneyOrDash(nowSub)),
                        const SizedBox(height: 6),
                        _kvCustom(context, 'IVA', moneyOrDash(nowTax)),
                        const SizedBox(height: 6),
                        _kvCustom(context, 'Total', moneyOrDash(nowTot, strong: true), isStrong: true),

                        const SizedBox(height: 14),

                        _sectionTitle(context, 'Próxima mensualidad'),
                        _kvCustom(context, 'Subtotal', moneyOrDash(nextSub)),
                        const SizedBox(height: 6),
                        _kvCustom(context, 'IVA', moneyOrDash(nextTax)),
                        const SizedBox(height: 6),
                        _kvCustom(context, 'Total', moneyOrDash(nextTot, strong: true), isStrong: true),
                      ],
                    );
                  }),

                  const SizedBox(height: 12),
                  _kv(context, 'Tipo de suscripción', 'Mensual'),
                  const SizedBox(height: 8),
                  _kv(context, 'Actualmente contratadas', '$currentSeats'),
                  const SizedBox(height: 8),
                  _kv(context, 'Nueva cantidad', '$newSeats'),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _sectionTitle(BuildContext ctx, String text) {
    final t = Theme.of(ctx);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: t.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: t.colorScheme.onSurface,
        ),
      ),
    );
  }

  String _fmtMoney(int cents, String currency) {
    final symbol = currency.toLowerCase() == 'eur' ? '€' : currency.toUpperCase();
    final fmt = NumberFormat.currency(locale: 'es_ES', symbol: symbol);
    return fmt.format(cents / 100).replaceAll(' ', '');
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

  Widget _kvCustom(BuildContext ctx, String k, Widget trailing, {bool isStrong = false}) {
    final t = Theme.of(ctx);
    final style = (isStrong ? t.textTheme.bodyLarge : t.textTheme.bodyMedium)?.copyWith(
      fontWeight: isStrong ? FontWeight.w800 : FontWeight.w500,
    );

    return Row(
      children: [
        Expanded(child: Text(k, style: style)),
        trailing,
      ],
    );
  }
}