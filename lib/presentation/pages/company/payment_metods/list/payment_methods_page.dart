import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:farmatime/presentation/presentation.dart';



class PaymentMethodsPage extends StatelessWidget {
  const PaymentMethodsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<PaymentMethodsController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Métodos de pago')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => c.addCard(context),
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        if (c.loading.value && c.methods.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: () => c.fetchMethods(),
          child: Column(
            children: [
              if (c.error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    c.error.value,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              if (c.methods.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No tienes tarjetas guardadas.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),

                ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: c.methods.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final pm = c.methods[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '**** ${pm.last4}',
                                          style: Get.theme.textTheme.headlineMedium,
                                        ),
                                      ),
                                      if (pm.isDefault)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primary.withOpacity(.12),
                                            borderRadius: BorderRadius.circular(100),
                                          ),
                                          child: Text(
                                            'Por defecto',
                                            style: Get.textTheme.bodySmall?.copyWith(
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                          ),
                                        )
                                      else
                                        PopupMenuButton<String>(
                                          onSelected: (v) async {
                                            if (v == 'default') {
                                              await c.makeDefault(pm);
                                            } else if (v == 'remove') {
                                              await c.remove(pm);
                                            }
                                          },
                                          itemBuilder: (_) => [
                                            const PopupMenuItem(
                                              value: 'default',
                                              child: Text('Marcar como predeterminada'),
                                            ),
                                            const PopupMenuItem(
                                              value: 'remove',
                                              child: Text('Eliminar'),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          pm.brand.toUpperCase(),
                                          style: Get.theme.textTheme.bodySmall?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: Get.theme.colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'Caduca ${pm.expMonth.toString().padLeft(2, '0')}/${pm.expYear}',
                                        style: Get.theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 32,
                              color: Theme.of(context).colorScheme.outline,
                            )
                          ],
                        ),
                      )
                    );
                  }
                ),
              // ...c.methods.map((pm) => Card(
              //   child: Padding(
              //     padding: const EdgeInsets.all(8),
              //   ),
                  // child: ListTile(
                  //   leading: Icon(c.iconForBrand(pm.brand)),
                  //   title: Text('${pm.brand.toUpperCase()} •••• ${pm.last4}'),
                  //   subtitle: Text('Caduca ${pm.expMonth.toString().padLeft(2, '0')}/${pm.expYear}'),
                  //   trailing: pm.isDefault
                  //       ? Container(
                  //           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  //           decoration: BoxDecoration(
                  //             color: Theme.of(context).colorScheme.primary.withOpacity(.12),
                  //             borderRadius: BorderRadius.circular(100),
                  //           ),
                  //           child: Text(
                  //             'Predeterminada',
                  //             style: TextStyle(
                  //               color: Theme.of(context).colorScheme.primary,
                  //               fontWeight: FontWeight.w700,
                  //             ),
                  //           ),
                  //         )
                  //       : PopupMenuButton<String>(
                  //           onSelected: (v) async {
                  //             if (v == 'default') {
                  //               await c.makeDefault(pm);
                  //             } else if (v == 'remove') {
                  //               await c.remove(pm);
                  //             }
                  //           },
                  //           itemBuilder: (_) => [
                  //             const PopupMenuItem(
                  //               value: 'default',
                  //               child: Text('Marcar como predeterminada'),
                  //             ),
                  //             const PopupMenuItem(
                  //               value: 'remove',
                  //               child: Text('Eliminar'),
                  //             ),
                  //           ],
                  //         ),
                  //   ),
                  // )),
            ],
          ),
        );
      }),
    );
  }
}