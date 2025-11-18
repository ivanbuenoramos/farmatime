import 'package:farmatime/presentation/widgets/card/base_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'confirm_seat_change_controller.dart';
import 'package:intl/intl.dart';

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
        // Usuario sale SIN confirmar
        Get.back(result: false);
        return false; // evitamos el pop por defecto
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Confirmar cambio de plan')),
        bottomNavigationBar: Obx(() {
          final loading = controller.loading.value;
          final canConfirm = controller.canConfirm;
      
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
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (!canConfirm || loading)
                      ? null
                      : () => controller.confirmAndPay(context),
                  child: loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Confirmar y continuar'),
                ),
              ),
            ),
          );
        }),
        body: Obx(() {
          final loading = controller.loading.value;
          final error = controller.error.value;
          final preview = controller.preview.value;
      
          if (loading && preview == null) {
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
      
          if (preview == null) {
            return const Center(child: Text('No se pudo cargar el resumen.'));
          }
      
          final isIncrease = newSeats > initialSeats;
          final monthlyNewCents =
              (newSeats > 1) ? (newSeats - 1) * 100 : 0; // 1ª gratis
          final monthlyOldCents =
              (initialSeats > 1) ? (initialSeats - 1) * 100 : 0;
      
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              BaseCard(
                title: 'Plazas',
                children: [
                  _kv(context, 'Plazas actuales', '$initialSeats'),
                  const SizedBox(height: 8),
                  _kv(context, 'Nuevas plazas', '$newSeats'),
                ],
              ),
              const SizedBox(height: 12),
              BaseCard(
                title: 'Importes mensuales',
                children: [
                  _kv(context, 'Antes', _fmtCents(monthlyOldCents)),
                  const SizedBox(height: 8),
                  _kv(context, 'Nuevo importe', _fmtCents(monthlyNewCents)),
                  const SizedBox(height: 8),
                  const Divider(),
                  _kv(
                    context,
                    'Diferencia mensual',
                    _fmtCents(monthlyNewCents - monthlyOldCents),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              BaseCard(
                title: 'Cargo prorrateado ahora',
                children: [
                  _kv(
                    context,
                    'Importe inmediato',
                    _fmtCents(preview.amountCents),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isIncrease
                        ? 'Se generará una factura prorrateada por la diferencia hasta el final del ciclo actual.'
                        : 'No se generará un cargo adicional si el total es 0 €.',
                    style: Get.textTheme.bodySmall,
                  ),
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