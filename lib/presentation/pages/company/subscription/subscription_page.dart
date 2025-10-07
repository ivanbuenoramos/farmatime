// 📄 lib/presentation/pages/company/subscription/subscription_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:farmatime/presentation/pages/company/subscription/subscription_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionPage extends StatelessWidget {
  const SubscriptionPage({super.key});

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  String _formatMoneyCents(int cents) {
    final euros = cents / 100.0;
    final n = NumberFormat.currency(locale: 'es_ES', symbol: '€');
    // Queremos "9,00€" sin símbolo delante
    return n.format(euros).replaceAll(' ', ''); // evita nbsp
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<SubscriptionController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar suscripción'),
      ),
      body: Obx(() {
        final int seats = c.contractedSeats.value;
        final DateTime? renewAt = c.currentPeriodEnd.value;
        final int monthlyCents = (seats > 0 ? (seats - 1) : 0) * 100; // 1€ por plaza, primera gratis

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ================= Próxima renovación =================
            Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle('Próxima renovación'),
                    const Divider(),
                    Row(
                      children: [
                        Expanded(
                          child: _InfoTile(
                            label: 'Tipo de suscripción',
                            value: 'Mensual',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _InfoTile(
                            label: 'Fecha',
                            value: _formatDate(renewAt),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _BigAmount(
                      label: 'Importe',
                      value: _formatMoneyCents(monthlyCents),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ================= Historial de facturas =================
            Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle('Historial de facturas'),
                    const Divider(),
                    InvoicesList(),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.secondary
              )
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontSize: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigAmount extends StatelessWidget {
  final String label;
  final String value;
  const _BigAmount({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.secondary
                )
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontSize: 26,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ---------- Lista de facturas ---------- */

class InvoicesList extends StatelessWidget {
  const InvoicesList({super.key});

  String _fmtDate(int? timestamp) {
    if (timestamp == null) return '-';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  String _fmtCents(num? cents) {
    final n = NumberFormat.currency(locale: 'es_ES', symbol: '€');
    return n.format((cents ?? 0) / 100).replaceAll(' ', '');
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SubscriptionController>();

    return Obx(() {
      final invoices = controller.invoices; // 👈 RxList en el controller

      if (controller.isLoading.value) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        );
      }

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
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 0),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: invoices.length,
        itemBuilder: (context, i) {
          final inv = invoices[i];
          final number = inv.number.toString();
          final created = inv.createdAt is int ? inv.createdAt as int : null;
          final amountCents = (inv.amountCents ) as num?;
          final pdfUrl = (inv.pdfUrl ?? '').toString();

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
              borderRadius: BorderRadius.circular(10),
              child: Ink(
                child: Row(
                  children: [
                    const _PdfBadge(),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '#$number',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                            )
                          ),
                          Text(
                            _fmtDate(created),
                            style: Theme.of(context).textTheme.bodyMedium
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _fmtCents(amountCents),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
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