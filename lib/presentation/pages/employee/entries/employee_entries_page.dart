
import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:collection/collection.dart';

import 'package:farmatime/presentation/pages/employee/entries/employee_entries_controller.dart';



class EmployeeEntriesPage extends GetView<EmployeeEntriesController> {
  const EmployeeEntriesPage({super.key});

  @override
  Widget build(BuildContext context) {

    String formatHour(DateTime dt) => DateFormat.Hm().format(dt);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis fichajes'),
      ),
      body: Obx(() {
        final grouped = controller.groupedClockIns;
        if (grouped.isEmpty) return const Center(child: Text('No hay fichajes'));
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: grouped.entries.map((entry) {
            final date = entry.key;
            final isToday = DateUtils.isSameDay(date, DateTime.now());
            final isYesterday = DateUtils.isSameDay(date, DateTime.now().subtract(const Duration(days: 1)));
            final title = isToday
                ? 'Hoy • ${_formatDate(date)}'
                : isYesterday
                    ? 'Ayer • ${_formatDate(date)}'
                    : _formatDate(date);

            // 👉 Espaciado inferior de 10 px entre días
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Get.theme.colorScheme.surface,
                  border: Border.all(color: Get.theme.colorScheme.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Get.textTheme.headlineSmall),
                    const Divider(),
                    ...entry.value
                        .sorted((a, b) => a.time.compareTo(b.time))
                        .map(
                          (e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      e.type == ClockInOutType.entry ? Icons.login : Icons.logout,
                                      color: e.type == ClockInOutType.entry ? Colors.blue : Colors.red,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      e.type == ClockInOutType.entry ? 'Entrada' : 'Salida',
                                      style: TextStyle(
                                        color: e.type == ClockInOutType.entry ? Colors.blue : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(formatHour(e.time)),
                              ],
                            ),
                          ),
                        )
                  ],
                ),
              ),
            );
          }).toList(),
        );
      }),
    );
  }

  String _formatDate(DateTime date) => DateFormat('d MMM yyyy', 'es').format(date);
}
