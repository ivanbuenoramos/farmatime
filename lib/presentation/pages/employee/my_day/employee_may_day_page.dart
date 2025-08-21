import 'package:farmatime/presentation/widgets/buttons/block_button.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:farmatime/presentation/pages/employee/my_day/employee_may_day_controller.dart';



class EmployeeMyDayPage extends GetView<EmployeeMyDayController> {
  const EmployeeMyDayPage({super.key});

  String formatHour(DateTime dt) => DateFormat.Hm().format(dt);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'farmatime',
          style: Get.theme.textTheme.headlineLarge?.copyWith(
            color: Get.theme.colorScheme.onPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 24,
            fontStyle:  FontStyle.italic,
          ),
        ),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 0, bottom: 10),
          child: CircleAvatar(
            backgroundColor: Get.theme.colorScheme.onPrimary,
          ),
        ),
      ),
      body: Obx(() {
        final entry = controller.currentEntry.value;
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  children: [
                    /// Bienvenida
                    Row(
                      children: [
                        const CircleAvatar(radius: 24),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '¡Hola ${controller.brain.employee.value?.name ?? ''}!',
                              style: Get.theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            
                            Text(
                              DateFormat('EEE. d MMM · HH:mm', 'es_ES').format(DateTime.now())
                            ),
                          ],
                        ),
                      ],
                    ),
              
                    const SizedBox(height: 20),
              
                    /// Estado
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Get.theme.colorScheme.surface,
                        border: Border.all(color: Get.theme.colorScheme.outline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Estado', style: Get.theme.textTheme.headlineSmall),
                              Text(
                                entry != null ? 'Entrada activa' : 'Sin entrada',
                                style: TextStyle(
                                  color: entry != null ? Get.theme.colorScheme.primary : Colors.grey,
                                  fontWeight: entry != null ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          Divider(),
                          if (entry != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Obx(() {
                                  final duration = controller.currentDuration.value;
                                  final h = duration.inHours;
                                  final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
                                  final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
              
                                  return Row(
                                    children: [
                                      Text(
                                        '$h:$m:$s ',
                                        style: TextStyle(color: Get.theme.colorScheme.primary, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        'desde mi última entrada (${formatHour(entry.clockIn)})'
                                      )
                                    ],
                                  );
                                }),
              
                                // const SizedBox(height: 4),
                                // Text(
                                //   'Tiempo trabajado hoy: ${controller.getFormattedWorkedToday()}',
                                //   style: TextStyle(color: Get.theme.colorScheme.primary),
                                // ),
                              ],
                            ),
                          if (entry == null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('No tengo ninguna entrada activa', style: TextStyle(color: Colors.grey)),
                                const SizedBox(height: 4),
                                Text(
                                  'Tiempo trabajado hoy: ${controller.getFormattedWorkedToday()}',
                                  style: TextStyle(color: Get.theme.colorScheme.primary),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
              
                    const SizedBox(height: 10),
              
                    /// Horario
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Get.theme.colorScheme.surface,
                        border: Border.all(color: Get.theme.colorScheme.outline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Horario de hoy', style: Get.theme.textTheme.headlineSmall),
                          Divider(),
                          Text('De 8:00 a 13:00'),
                          Text('De 16:00 a 19:00'),
                        ],
                      ),
                    ),
              
                    const SizedBox(height: 10),
              
                    /// Fichajes de hoy
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Get.theme.colorScheme.surface,
                        border: Border.all(color: Get.theme.colorScheme.outline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Fichajes de hoy', style: Get.theme.textTheme.headlineSmall),
                          Divider(),
                          Obx(() {
                            final fichajes = controller.todayEntries.expand((entry) {
                              final list = <Map<String, dynamic>>[];
                              list.add({
                                'type': 'entrada',
                                'time': entry.clockIn,
                              });
                              if (entry.clockOut != null) {
                                list.add({
                                  'type': 'salida',
                                  'time': entry.clockOut!,
                                });
                              }
                              return list;
                            }).toList()
                              ..sort((a, b) => a['time'].compareTo(b['time'])); // Ordena cronológicamente
              
                            return Column(
                              children: fichajes.map((fichaje) {
                                final isEntrada = fichaje['type'] == 'entrada';
                                final time = fichaje['time'] as DateTime;
                                
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 5),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            isEntrada ? Icons.login : Icons.logout,
                                            color: isEntrada ? Colors.blue : Colors.red,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            isEntrada ? 'Entrada' : 'Salida',
                                            style: TextStyle(
                                              color: isEntrada ? Colors.blue : Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(formatHour(time)),
                                    ],
                                  ),
                                );
              
                              }).toList(),
                            );
                          }),
                        ],
                      ),
                    ),
              
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: BlockButton(
                      onPressed: entry == null ? controller.clockIn : null,
                      height: 40,
                      label: 'ENTRADA',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BlockButton(
                      onPressed: entry != null ? controller.clockOut : null,
                      height: 40,
                      label: 'SALIDA',
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}
