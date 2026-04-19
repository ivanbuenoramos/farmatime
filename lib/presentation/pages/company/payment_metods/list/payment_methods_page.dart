import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:get/get.dart';

import 'package:farmatime/presentation/presentation.dart';



class PaymentMethodsPage extends StatelessWidget {
  const PaymentMethodsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<PaymentMethodsController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Métodos de pago')),
      floatingActionButton: Obx(() => Opacity(
          opacity: c.loading.value ? 0.5 : 1,
          child: FloatingActionButton(
            heroTag: 'payment_methods_fab',
            onPressed: c.loading.value
            ? null
            : () => c.addCard(context),
            child: c.loading.value
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.add),
          ),
        ),
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
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            'assets/icons/no_payment_bold.svg',
                            height: 100,
                            colorFilter: ColorFilter.mode(
                              Theme.of(context).colorScheme.primary,
                              BlendMode.srcIn,
                            ),
                          ),
                          Text(
                            'No tienes tarjetas guardadas.',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Agrega una tarjeta para realizar pagos de manera rápida y segura.',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          OutlinedButton.icon(
                            onPressed: () => c.addCard(context),
                            icon: const Icon(Icons.payment_rounded),
                            label: const Text('Agregar tarjeta'),
                          ),
                          const SizedBox(height: 200),
                        ],
                      ),
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
                            SvgPicture.asset(
                              'assets/icons/bank_card.svg',
                              height: 32,
                              colorFilter: ColorFilter.mode(
                                Theme.of(context).colorScheme.primary,
                                BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(width: 10),
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
                                          style: Get.theme.textTheme.headlineSmall,
                                        ),
                                      ),
                                      // if (pm.isDefault)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.greenAccent.shade400.withOpacity(.12),
                                            borderRadius: BorderRadius.circular(100),
                                          ),
                                          child: Text(
                                            'Por defecto',
                                            style: Get.textTheme.bodySmall?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.greenAccent.shade700,
                                            ),
                                          ),
                                        )
                                      // else
                                      //   PopupMenuButton<String>(
                                      //     onSelected: (v) async {
                                      //       if (v == 'default') {
                                      //         await c.makeDefault(pm);
                                      //       } else if (v == 'remove') {
                                      //         await c.remove(pm);
                                      //       }
                                      //     },
                                      //     itemBuilder: (_) => [
                                      //       const PopupMenuItem(
                                      //         value: 'default',
                                      //         child: Text('Marcar como predeterminada'),
                                      //       ),
                                      //       const PopupMenuItem(
                                      //         value: 'remove',
                                      //         child: Text('Eliminar'),
                                      //       ),
                                      //     ],
                                      //   ),
                                    ],
                                  ),
                                  SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Caduca ${pm.expMonth.toString().padLeft(2, '0')}/${pm.expYear}',
                                          style: Get.theme.textTheme.bodySmall,
                                        ),
                                      ),
                                      Text(
                                        pm.brand.toUpperCase(),
                                        style: Get.theme.textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: Get.theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
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