import 'package:farmatime/data/models/schedule/day_entry.dart';
import 'package:farmatime/presentation/widgets/card/profile_avatar.dart';
import 'package:farmatime/presentation/widgets/schedule/schedule_calendar.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

import 'package:farmatime/presentation/widgets/card/base_card.dart';
import 'package:farmatime/presentation/pages/company/employee_detail/company_employee_detail_controller.dart';

// ▼ import NUEVO: calendario reusable

class EmployeeDetailPage extends GetView<EmployeeDetailController> {
  const EmployeeDetailPage({super.key});

  String formatHour(DateTime dt) => DateFormat.Hm().format(dt);
  String formatDate(DateTime dt) => DateFormat('d/M/yy').format(dt);
  String formatDiff(Duration diff) => '+${diff.inMinutes}m';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil de empleado'),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, color: Get.theme.colorScheme.secondary),
                    const SizedBox(width: 8),
                    Text(
                      'Editar empleado',
                      style: TextStyle(color: Get.theme.colorScheme.secondary),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_rounded, color: Get.theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Text(
                      'Eliminar empleado',
                      style: TextStyle(color: Get.theme.colorScheme.error),
                    ),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
      body: Obx(() {
        final employee = controller.employee.value;
        if (employee == null) return const SizedBox();

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BaseCard(
                title: 'Información',
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ProfileAvatar(
                        imageUrl: employee.photoUrl,
                        name: employee.name,
                        size: 60,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              employee.name,
                              style: Get.textTheme.headlineSmall,
                            ),
                            Text(
                              employee.role.name,
                              style: Get.textTheme.bodyMedium
                            ),
                            Text(
                              employee.workdayType?.name ?? 'Jornada no definida',
                              style: Get.textTheme.bodyMedium
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 12),

              BaseCard(
                title: 'Vacaciones y asuntos propios',
                children: [
                  Text(
                    'Estos son los días disponibles para el empleado:', 
                    style: Get.textTheme.bodyMedium
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Get.theme.colorScheme.error.withAlpha(10),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Get.theme.colorScheme.error),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Vacaciones',
                                style: TextStyle(color: Get.theme.colorScheme.error),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                '${controller.balances.value?.vacationAvailable.round()}',
                                style: Get.textTheme.headlineMedium?.copyWith(
                                  color: Get.theme.colorScheme.error,
                                ),
                              ),
                            ],
                          ),
                        )
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Get.theme.colorScheme.tertiary.withAlpha(10),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Get.theme.colorScheme.tertiary),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Asuntos propios',
                                style: TextStyle(color: Get.theme.colorScheme.tertiary),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                '${controller.balances.value?.personalAvailable.round()}',
                                style: Get.textTheme.headlineMedium?.copyWith(
                                  color: Get.theme.colorScheme.tertiary,
                                ),
                              ),
                            ],
                          ),
                        )
                      ),

                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ───────────────────────────────────────────────────
              // FICHAJES (tal cual)
              // ───────────────────────────────────────────────────
              BaseCard(
                title: 'Fichajes',
                actions: [
                  Obx(() {
                    final monthStr = DateFormat.MMMM('es_ES').format(controller.selectedMonth.value);
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: controller.prevMonth,
                          child: const Icon(Icons.chevron_left_rounded, color: Colors.blue),
                        ),
                        Text(monthStr, style: Get.textTheme.bodyMedium?.copyWith(
                          color: Get.theme.colorScheme.primary,
                        )),
                        GestureDetector(
                          onTap: controller.nextMonth,
                          child:  Icon(Icons.chevron_right_rounded, color: Get.theme.colorScheme.tertiary),
                        ),
                      ],
                    );
                  }),
                ],
                children: [
                  Obx(() {
                    final month = controller.selectedMonth.value;
                    final filtered = controller.groupedClockIns
                        .entries
                        .where((e) => e.key.year == month.year && e.key.month == month.month)
                        .toList()
                      ..sort((a, b) => b.key.compareTo(a.key));

                    if (filtered.isEmpty) {
                      return const Center(child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Sin fichajes este mes'),
                      ));
                    }

                    return DataTable(
                      headingRowHeight: 32,
                      dataRowMinHeight: 32,
                      columnSpacing: 14,
                      columns: const [
                        DataColumn(label: Text('Día')),
                        DataColumn(label: Text('Empl.')),
                        DataColumn(label: Text('Fich.')),
                        DataColumn(label: Text('Prev.')),
                        DataColumn(label: Text('Trab.')),
                        DataColumn(label: Text('Dif.')),
                      ],
                      rows: filtered.map((dayGroup) {
                        final items = dayGroup.value.sorted((a, b) => a.time.compareTo(b.time));
                        Duration worked = Duration.zero;
                        for (var i = 0; i < items.length; i += 2) {
                          if (i + 1 < items.length && items[i].type == ClockInOutType.entry) {
                            final out = items[i + 1];
                            if (out.type == ClockInOutType.exit) {
                              worked += out.time.difference(items[i].time);
                            }
                          }
                        }
                        final workedText =
                            '${worked.inHours}:${worked.inMinutes.remainder(60).toString().padLeft(2, '0')}';
                        final diff = worked - const Duration(hours: 8);
                        final diffText =
                            '${diff.isNegative ? '' : '+'}${diff.inMinutes}m';

                        return DataRow(cells: [
                          DataCell(Text(DateFormat('d/M').format(dayGroup.key))),
                          DataCell(Text(employee.name)),
                          DataCell(Text('${items.length ~/ 2}')),
                          const DataCell(Text('8h')),
                          DataCell(Text(workedText)),
                          DataCell(Text(diffText,
                              style: TextStyle(
                                  color: diff.isNegative ? Colors.red : Colors.blue))),
                        ]);
                      }).toList(),
                    );
                  }),
                ],
              ),

              const SizedBox(height: 12),

              // ───────────────────────────────────────────────────
              // CALENDARIO DE HORARIO (NUEVO)
              // ───────────────────────────────────────────────────
              BaseCard(
                title: 'Calendario',
                actions: [
                  GestureDetector(
                    onTap: () => controller.redirectToEmployeeSchedule(),
                    child: Icon(Icons.edit_rounded, color: Get.theme.colorScheme.primary, size: 18),
                  ),
                ],
                children: [
                  Obx(() {
                    if (controller.isLoadingSchedule.value && controller.scheduleOverrides.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    return EmployeeScheduleCalendar(
                      firstDay: DateTime.utc(DateTime.now().year - 1, 1, 1),
                      lastDay:  DateTime.utc(DateTime.now().year + 2, 12, 31),
                      focusedDay: controller.calendarFocusedDay.value,
                      selectedDay: null,
                      rangeStart: null,
                      rangeEnd: null,
                      overridesByDay: Map<DateTime, dynamic>.from(controller.scheduleOverrides).cast<DateTime, DayEntry>(),
                      rules: controller.scheduleRules,
                      onPageChanged: controller.onCalendarPageChanged,
                      locale: 'es_ES',
                      showTimes: true,
                      compact: true,
                    );
                  }),
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        );
      }),
    );
  }
}
