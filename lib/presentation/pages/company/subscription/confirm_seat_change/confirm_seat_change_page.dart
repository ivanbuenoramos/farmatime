import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:farmatime/presentation/widgets/card/base_card.dart';
import 'confirm_seat_change_controller.dart';

class ConfirmSeatChangePage extends GetView<ConfirmSeatChangeController> {
  final int initialSeats;
  final int newSeats;

  const ConfirmSeatChangePage({
    super.key,
    required this.initialSeats,
    required this.newSeats,
  });

  String _fmtCents(int cents) {
    final fmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');
    return fmt.format(cents / 100).replaceAll(' ', '');
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Get.back(result: false);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Confirmar cambio')),
        bottomNavigationBar: Obx(() {
          final loading = controller.loading.value;
          final canConfirm = controller.canConfirm;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Get.theme.colorScheme.surface,
              border: Border(top: BorderSide(color: Get.theme.colorScheme.outline)),
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (!canConfirm || loading) ? null : () => controller.confirm(context),
                  child: loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Confirmar'),
                ),
              ),
            ),
          );
        }),
        body: Obx(() {
          final loading = controller.loading.value;
          final error = controller.error.value;
          final p = controller.preview.value;

          if (loading && p == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (error.isNotEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  error,
                  textAlign: TextAlign.center,
                  style: Get.textTheme.bodyMedium?.copyWith(
                    color: Get.theme.colorScheme.error,
                  ),
                ),
              ),
            );
          }

          if (p == null) {
            return const Center(child: Text('No se pudo cargar el resumen.'));
          }

          final isIncrease = newSeats > initialSeats;
          final monthlyNewCents = (newSeats > 1) ? (newSeats - 1) * 100 : 0;
          final monthlyOldCents = (initialSeats > 1) ? (initialSeats - 1) * 100 : 0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              BaseCard(
                title: 'Plazas',
                children: [
                  _kv(context, 'Actuales', '$initialSeats'),
                  const SizedBox(height: 8),
                  _kv(context, 'Nuevas', '$newSeats'),
                ],
              ),
              const SizedBox(height: 12),
              BaseCard(
                title: 'Importe mensual',
                children: [
                  _kv(context, 'Antes', _fmtCents(monthlyOldCents)),
                  const SizedBox(height: 8),
                  _kv(context, 'Nuevo', _fmtCents(monthlyNewCents)),
                ],
              ),
              const SizedBox(height: 12),
              BaseCard(
                title: isIncrease ? 'Cargo ahora (prorrateo)' : 'Aplicación del cambio',
                children: [
                  if (isIncrease) ...[
                    _kv(context, 'Estimación', _fmtCents(p.prorationCents)),
                    const SizedBox(height: 8),
                    Text(
                      'Se intentará cobrar automáticamente con tu método de pago actual. '
                      'Si es necesario, se te pedirá confirmación.',
                      style: Get.textTheme.bodySmall,
                    ),
                  ] else ...[
                    Text(
                      p.scheduledAtPeriodEnd
                          ? 'La reducción se aplicará en la próxima renovación.'
                          : 'No se aplicará ningún cargo ahora.',
                      style: Get.textTheme.bodySmall,
                    ),
                    if (p.scheduledForPeriodEnd != null) ...[
                      const SizedBox(height: 8),
                      _kv(
                        context,
                        'Fecha estimada',
                        DateFormat('dd/MM/yyyy').format(p.scheduledForPeriodEnd!.toLocal()),
                      ),
                    ],
                  ],
                ],
              ),
            ],
          );
        }),
      ),
    );
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
}