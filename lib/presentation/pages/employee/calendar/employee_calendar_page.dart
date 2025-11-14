// lib/presentation/pages/employee/calendar/employee_calendar_page.dart
import 'package:farmatime/presentation/pages/employee/calendar/employee_calendar_controller.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/svg.dart';

import 'package:farmatime/presentation/widgets/schedule/schedule_calendar.dart';



class EmployeeCalendarPage extends GetView<EmployeeCalendarController> {
  const EmployeeCalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi calendario'),
        titleSpacing: 16,
        actions: [
          IconButton(
            icon: SvgPicture.asset(
              'assets/icons/hand_up_bold.svg',
              colorFilter: ColorFilter.mode(
                Get.theme.colorScheme.onPrimary,
                BlendMode.srcIn,
              ),
              width: 24,
              height: 24,
            ),
            onPressed: controller.redirectToRequestLeave,
            tooltip: 'Solicitar vacaciones y permisos',
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.overridesByDay.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        final day = controller.selectedDay.value;
        final shifts = controller.shiftsFor(day);
        final isVacation = controller.isVacation(day);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            children: [
              // Tu widget de calendario de horarios
              Card(
                child: EmployeeScheduleCalendar(
                  firstDay: controller.firstDay.value,
                  lastDay: controller.lastDay.value,
                  focusedDay: controller.focusedDay.value,
                  overridesByDay: controller.overridesByDay,
                  rules: controller.rules,
                  locale: 'es_ES',
                  onDaySelected: controller.onDaySelected,
                  onPageChanged: controller.onCalendarPageChanged,
                ),
              ),
          
              const SizedBox(height: 12),
          
              // Panel de información del día
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, d MMMM y', 'es_ES').format(day),
                        style: Get.theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text('Horario asignado:', style: Get.theme.textTheme.bodyMedium),
                      const SizedBox(height: 4),
                      if (shifts.isEmpty)
                        Text('—', style: Get.theme.textTheme.bodyMedium)
                      else
                        ...shifts.map((t) => Text(t)),
                      const SizedBox(height: 12),
                      Text('Estado del día:', style: Get.theme.textTheme.bodyMedium),
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
          ),
        );
      }),
    );
  }
}
