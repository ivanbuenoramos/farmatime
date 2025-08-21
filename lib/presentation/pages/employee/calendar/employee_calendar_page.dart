// lib/presentation/pages/employee/calendar/employee_calendar_page.dart
import 'package:farmatime/presentation/pages/employee/calendar/employee_calendar_controller.dart';
import 'package:farmatime/presentation/widgets/schedule/schedule_calendar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class EmployeeCalendarPage extends GetView<EmployeeCalendarController> {
  const EmployeeCalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi calendario')),
      body: Obx(() {
        if (controller.isLoading.value && controller.overridesByDay.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final day = controller.selectedDay.value;
        final shifts = controller.shiftsFor(day);
        final isVacation = controller.isVacation(day);

        return Column(
          children: [
            // Tu widget de calendario de horarios
            EmployeeScheduleCalendar(
              firstDay: controller.firstDay.value,
              lastDay: controller.lastDay.value,
              focusedDay: controller.focusedDay.value,
              overridesByDay: controller.overridesByDay, // Map<String, DayEntry>
              rules: controller.rules,                   // List<RecurringShiftRule>
              // Si tu widget tiene estos callbacks, descomenta y conecta:
              onDaySelected: controller.onDaySelected,
              onPageChanged: controller.onCalendarPageChanged,
            ),

            const SizedBox(height: 16),

            // Panel de información del día
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Get.theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Get.theme.colorScheme.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, d MMMM y', 'es_ES').format(day),
                      style: Get.theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Divider(),

                    Text('Horario asignado:', style: Get.theme.textTheme.bodyLarge),
                    const SizedBox(height: 4),
                    if (shifts.isEmpty)
                      Text('—', style: Get.theme.textTheme.bodyMedium)
                    else
                      ...shifts.map((t) => Text(t)),

                    const SizedBox(height: 12),
                    Text('Estado del día:', style: Get.theme.textTheme.bodyLarge),
                    const SizedBox(height: 4),
                    Text(
                      isVacation ? '🟢 Vacaciones' : '🟦 Jornada laboral',
                      style: Get.theme.textTheme.bodyMedium,
                    ),

                    if (controller.errorText.value != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        controller.errorText.value!,
                        style: Get.theme.textTheme.bodySmall?.copyWith(color: Get.theme.colorScheme.error),
                      ),
                    ],
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
