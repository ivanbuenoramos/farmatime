import 'package:farmatime/presentation/widgets/card/base_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:farmatime/presentation/pages/company/subscription/subscription_controller.dart';

class SubscriptionPage extends StatelessWidget {
  const SubscriptionPage({super.key});

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  String _formatMoneyCents(int cents) {
    final euros = cents / 100.0;
    final n = NumberFormat.currency(locale: 'es_ES', symbol: '€');
    return n.format(euros).replaceAll(' ', '');
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<SubscriptionController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Configurar suscripción')),
      body: Obx(() {
        final seats = c.contractedSeats.value;
        final renewAt = c.currentPeriodEnd.value;
        final monthlyCents = (seats > 1 ? seats - 1 : 0) * 100;

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          physics: const BouncingScrollPhysics(),
          children: [
            _BillingStatusBanner(
              status: c.billingStatus.value,
              onManage: c.redirectToSeatCheckout,
            ),

            const SizedBox(height: 12),

            // ===== Próxima renovación =====
            BaseCard(
              title: 'Próxima renovación',
              children: [
                Row(
                  children: [
                    _Chip('Facturación', 'Mensual'),
                    const SizedBox(width: 10),
                    _Chip('Fecha', _formatDate(renewAt)),
                  ],
                ),
                const SizedBox(height: 10),
                _AmountRow(label: 'Importe', value: _formatMoneyCents(monthlyCents)),
              ],
            ),

            const SizedBox(height: 12),

            // ===== Selector de plazas + prorrateo =====
            // BaseCard(
            //   title: 'Plazas contratadas',
            //   children: [
            //     Row(
            //       children: [
            //         const Text('Prorratear cambios'),
            //         const Spacer(),
            //         Switch(
            //           value: c.prorationBehavior.value == 'create_prorations',
            //           onChanged: (v) => c.prorationBehavior.value =
            //               v ? 'create_prorations' : 'none',
            //         ),
            //       ],
            //     ),
            //     const SizedBox(height: 8),
            //     Row(
            //       children: [
            //         IconButton(
            //           onPressed: c.decrement,
            //           icon: const Icon(Icons.remove_circle_outline),
            //         ),
            //         Text(
            //           '${c.contractedSeats.value}',
            //           style: Theme.of(context).textTheme.headlineSmall,
            //         ),
            //         IconButton(
            //           onPressed: c.increment,
            //           icon: const Icon(Icons.add_circle_outline),
            //         ),
            //         const Spacer(),
            //         Text(
            //           'Total: ${_formatMoneyCents(monthlyCents)} / mes',
            //           style: Theme.of(context).textTheme.titleMedium,
            //         ),
            //       ],
            //     ),
            //   ],
            // ),

            // const SizedBox(height: 12),

            // ===== Botón Billing Portal =====
            // _ManagePaymentButton(onTap: c.openBillingPortal),

            // const SizedBox(height: 16),

            // ===== Historial de facturas (desde controller.invoices) =====
            BaseCard(
              title: 'Historial de facturas',
              children: [
                InvoicesList(),
              ] 
            ),
          ],
        );
      }),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label, value;
  const _Chip(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border.all(color: cs.outline),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: cs.primary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label, value;
  const _AmountRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outline),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: cs.primary
            ),
          ),
        ],
      ),
    );
  }
}

class _BillingStatusBanner extends StatelessWidget {
  final String status; // active | incomplete | past_due | canceled...
  final VoidCallback onManage;
  const _BillingStatusBanner({required this.status, required this.onManage});

  @override
  Widget build(BuildContext context) {
    // if (status.isEmpty || status == 'active') return const SizedBox.shrink();

    late Color bg;
    late String text;
    late String cta;

    switch (status) {
      // case 'incomplete':
      //   bg = Colors.red.shade100;
      //   text = 'Configura un método de pago para activar la suscripción.';
      //   cta = 'Configurar pago';
      //   break;
      // case 'past_due':
      //   bg = Colors.orange.shade100;
      //   text = 'Hay pagos pendientes. Revisa tu método de pago.';
      //   cta = 'Gestionar pago';
      //   break;
      // case 'canceled':
      //   bg = Colors.grey.shade100;
      //   text = 'Suscripción cancelada. Puedes reactivarla.';
      //   cta = 'Gestionar';
      //   break;
      // case 'active':
      //   bg = Colors.blue.shade100;
      //   text = 'Suscripción activa.';
      //   cta = 'Gestionar';
      //   break;
      default:
        bg = Colors.blue.shade100;
        text = 'Estado: $status';
        cta = 'Gestionar';
    }

    return Container(
      decoration:BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.info_outline),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
          TextButton(onPressed: onManage, child: Text(cta)),
        ],
      ),
    );
  }
}

class _ManagePaymentButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ManagePaymentButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.open_in_new),
        label: const Text('Gestionar pago y facturación'),
      ),
    );
  }
}

/* ---------- Lista de facturas (usa controller.invoices) ---------- */

class InvoicesList extends StatelessWidget {
  const InvoicesList({super.key});

  String _fmtDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  String _fmtCents(num? cents) {
    final n = NumberFormat.currency(locale: 'es_ES', symbol: '€');
    return n.format((cents ?? 0) / 100).replaceAll(' ', '');
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SubscriptionController>();

    return Obx(() {
      if (controller.invoicesLoading.value) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        );
      }

      final invoices = controller.invoices;
      if (invoices.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Aún no hay facturas.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey[600]),
          ),
        );
      }

      return ListView.separated(
        padding: EdgeInsets.zero,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: invoices.length,
        itemBuilder: (context, i) {
          final inv = invoices[i];
          final number = inv.number;
          final date = inv.createdAt; // DateTime en tu InvoiceModel
          final amountCents = inv.amountCents;
          final pdfUrl = inv.pdfUrl ?? '';

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: pdfUrl.isNotEmpty
                  ? () async {
                      final uri = Uri.parse(pdfUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    }
                  : null,
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withOpacity(.25),
                  ),
                ),
                child: Row(
                  children: [
                    const _PdfBadge(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('#$number',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(_fmtDate(date),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    Text(
                      _fmtCents(amountCents),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
          );
        },
      );
    });
  }
}

class _PdfBadge extends StatelessWidget {
  const _PdfBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(.1),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        'PDF',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}