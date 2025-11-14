// lib/presentation/pages/employee/calendar/employee_calendar_controller.dart
import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/routes/routes.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:farmatime/domain/repositories/employee_schedule_repository.dart';
import 'package:farmatime/data/models/schedule/day_entry.dart';
import 'package:farmatime/data/models/schedule/recurring_shift_rule.dart';

class EmployeeCalendarController extends GetxController {
  EmployeeCalendarController(this.scheduleRepo);

  final EmployeeScheduleRepository scheduleRepo;
  final Brain brain = Get.find<Brain>();

  // Estado del calendario
  final Rx<DateTime> selectedDay = DateTime.now().obs;
  final Rx<DateTime> focusedDay  = DateTime.now().obs;

  // Rango visible
  late final Rx<DateTime> firstDay = DateTime(DateTime.now().year - 1, 1, 1).obs;
  late final Rx<DateTime> lastDay  = DateTime(DateTime.now().year + 1, 12, 31).obs;

  // Datos para el widget
  final overridesByDay = <DateTime, DayEntry>{}.obs;     // ahora DateTime → DayEntry
  final rules = <RecurringShiftRule>[].obs;

  // Estado
  final isLoading = false.obs;
  final errorText = RxnString();

  // Cache por año
  final Map<int, Map<DateTime, DayEntry>> _yearCache = {};
  bool _rulesLoaded = false;

  @override
  void onInit() {
    super.onInit();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _ensureDataForYear(focusedDay.value.year);
  }

  void onDaySelected(DateTime selected, DateTime focused) async {
    selectedDay.value = DateTime(selected.year, selected.month, selected.day);
    if (focused.year != focusedDay.value.year) {
      await _ensureDataForYear(focused.year);
    }
    focusedDay.value = DateTime(focused.year, focused.month, focused.day);
  }

  Future<void> onCalendarPageChanged(DateTime newFocusedDay) async {
    if (newFocusedDay.year != focusedDay.value.year) {
      await _ensureDataForYear(newFocusedDay.year);
    }
    focusedDay.value = DateTime(newFocusedDay.year, newFocusedDay.month, newFocusedDay.day);
  }

  Future<void> _ensureDataForYear(int year) async {
    isLoading.value = true;
    errorText.value = null;
    try {
      final companyId = brain.employee.value!.companyId;
      final employeeId = brain.employee.value!.uid; // ajusta según tu modelo

      if (!_yearCache.containsKey(year)) {
        final res = await scheduleRepo.getYear(
          companyId: companyId,
          employeeId: employeeId,
          year: year,
        );
        if (!res.success) {
          errorText.value = 'No se pudo cargar el calendario ($year): ${res.errorCode}';
          _yearCache[year] = {};
        } else {
          // 🔑 Convertimos claves yyyy-MM-dd a DateTime
          final mapped = <DateTime, DayEntry>{};
          res.data.forEach((key, entry) {
            final dt = DateFormat('yyyy-MM-dd').parse(key);
            mapped[dt] = entry;
          });
          _yearCache[year] = mapped;
        }
      }

      if (!_rulesLoaded) {
        final r = await scheduleRepo.listRecurringRules(
          companyId: companyId,
          employeeId: employeeId,
        );
        if (r.success) {
          rules.assignAll(r.data); 
        } else {
          errorText.value = 'No se pudieron cargar las reglas: ${r.errorCode}';
        }
        _rulesLoaded = true;
      }

      overridesByDay
        ..clear()
        ..addAll(_yearCache[year] ?? {});
    } catch (e) {
      errorText.value = 'Error al cargar calendario: $e';
    } finally {
      isLoading.value = false;
    }
  }

  // Helpers
  DayEntry? entryFor(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    return overridesByDay[normalized];
  }

  bool isVacation(DateTime day) {
    final e = entryFor(day);
    if (e == null) return false;
    final map = e.toJson();
    final type = (map['type'] ?? map['kind'] ?? 'work') as String;
    return type == 'vacation' || type == 'holiday' || type == 'off';
  }

  List<String> shiftsFor(DateTime day) {
    final e = entryFor(day);
    if (e == null) return const [];
    final map = e.toJson();
    final raw = (map['shifts'] as List?) ?? (map['periods'] as List?) ?? const [];
    final out = <String>[];
    for (final s in raw) {
      final m = Map<String, dynamic>.from(s as Map);
      final start = (m['start'] ?? m['open']) as String?;
      final end   = (m['end']   ?? m['close']) as String?;
      if (start != null && end != null) out.add('• De $start a $end');
    }
    return out;
  }

  void redirectToRequestLeave() {
    Get.toNamed(Routes.employeeRequestLeave);
  }
}
