import 'dart:async';

import 'package:farmatime/data/models/employee_shift_model.dart';
import 'package:farmatime/domain/usecases/employee_schedule/get_expected_shift_usecase.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/clock_in_out_model.dart';
import 'package:farmatime/domain/usecases/clock/create_entry_usecase.dart';
import 'package:farmatime/domain/usecases/clock/update_entry_usecase.dart';
import 'package:farmatime/domain/usecases/clock/get_entries_by_employee_usecase.dart';

class EmployeeMyDayController extends GetxController {
  final CreateEntryUseCase createEntryUseCase;
  final UpdateEntryUseCase updateEntryUseCase;
  final GetEntriesByEmployeeUseCase getEntriesByEmployeeUseCase;
  final GetExpectedShiftsForDayUseCase getExpectedShiftUseCase;

  EmployeeMyDayController({
    required this.createEntryUseCase,
    required this.updateEntryUseCase,
    required this.getEntriesByEmployeeUseCase,
    required this.getExpectedShiftUseCase,
  });

  final Brain brain = Get.find<Brain>();

  final currentEntry = Rxn<ClockInOutModel>();
  final todayEntries = <ClockInOutModel>[].obs;
  final isLoading = false.obs;

  Timer? _clockTimer;
  final currentDuration = Rx<Duration>(Duration.zero);

  // --- Horario real de hoy (start/end) ---
  final todayExpected = Rxn<ExpectedShiftModel>();

  // --- Contador (faltan / vas tarde) ---
  final scheduleCounterText = RxnString();
  Timer? _scheduleTimer;

  @override
  void onInit() {
    super.onInit();
    _loadInitialData();
  }

  @override
  void onClose() {
    _clockTimer?.cancel();
    _scheduleTimer?.cancel();
    super.onClose();
  }

  bool get isLateForShift {
    final expected = todayExpected.value;
    if (expected == null) return false;
    if (_hasClockedInToday()) return false; // si ya fichó, no aplica
    return DateTime.now().isAfter(expected.start);
  }

  Future<void> _loadInitialData() async {
    isLoading.value = true;

    final employee = brain.employee.value;
    final employeeId = employee?.uid;
    if (employeeId == null) {
      isLoading.value = false;
      return;
    }

    final allEntriesResult = await getEntriesByEmployeeUseCase.call(employeeId);

    if (allEntriesResult.success) {
      final all = List<ClockInOutModel>.from(allEntriesResult.data)
        ..sort((a, b) => b.clockIn.compareTo(a.clockIn)); // más reciente primero

      // Entrada activa = último fichaje sin clockOut
      if (all.isNotEmpty && all.first.clockOut == null) {
        currentEntry.value = all.first;
        _startClockTimer();
      } else {
        currentEntry.value = null;
        _clockTimer?.cancel();
        currentDuration.value = Duration.zero;
      }

      // Fichajes de hoy
      final now = DateTime.now();
      todayEntries.assignAll(
        all.where((e) => _isSameDay(e.clockIn, now)).toList(),
      );
    } else {
      Get.snackbar('Error', 'No se pudieron cargar fichajes');
    }

    // Horario real de hoy (override mensual + reglas dentro del usecase)
    await _loadTodayExpectedShift();

    // Timer del contador horario
    _startScheduleTimer();

    isLoading.value = false;
  }

  Future<void> _loadTodayExpectedShift() async {
    final employee = brain.employee.value;
    if (employee == null) {
      todayExpected.value = null;
      scheduleCounterText.value = null;
      return;
    }

    final now = DateTime.now();
    final dayDate = DateTime(now.year, now.month, now.day);

    final map = await getExpectedShiftUseCase.call(
      companyId: employee.companyId,
      employeeIds: [employee.uid],
      dayDate: dayDate,
    );

    todayExpected.value = map[employee.uid]; // null = no trabaja hoy
    _recomputeScheduleCounter();
  }

  void _startScheduleTimer() {
    _scheduleTimer?.cancel();
    _scheduleTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _recomputeScheduleCounter();
    });
  }

  void _startClockTimer() {
    _clockTimer?.cancel();

    final clockIn = currentEntry.value?.clockIn;
    if (clockIn == null) return;

    currentDuration.value = DateTime.now().difference(clockIn);

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      currentDuration.value = DateTime.now().difference(clockIn);
    });
  }

  void _recomputeScheduleCounter() {
    final expected = todayExpected.value;

    if (expected == null) {
      scheduleCounterText.value = null;
      return;
    }

    if (_hasClockedInToday()) {
      scheduleCounterText.value = null;
      return;
    }

    final now = DateTime.now();
    final start = expected.start;

    final String next = now.isBefore(start)
        ? _fmtHms(start.difference(now))
        : _fmtHms(now.difference(start));

    if (scheduleCounterText.value != next) {
      scheduleCounterText.value = next;
    } else {
      scheduleCounterText.refresh();
    }
  }

  bool _hasClockedInToday() {
    if (todayEntries.isEmpty) return false;
    return todayEntries.any((e) => _isSameDay(e.clockIn, DateTime.now()));
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _fmtHms(Duration d) {
    final total = d.inSeconds;
    final h = (total ~/ 3600).toString().padLeft(2, '0');
    final m = ((total % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  // --- Ubicación segura ---
  Future<Position?> _getSafePosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Get.snackbar(
          'Ubicación desactivada',
          'Activa la ubicación del dispositivo para registrar dónde fichas.',
        );
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Get.snackbar(
            'Permiso denegado',
            'No se ha concedido permiso de ubicación. Se registrará el fichaje sin ubicación.',
          );
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        Get.snackbar(
          'Permiso bloqueado',
          'Los permisos de ubicación están bloqueados. Actívalos en ajustes para registrar la ubicación.',
        );
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      Get.snackbar('Error ubicación', 'No se pudo obtener la ubicación.');
      return null;
    }
  }

  Future<void> clockOut() async {
    final entry = currentEntry.value;
    if (entry == null) return;

    final now = DateTime.now();
    final position = await _getSafePosition();

    final updated = entry.copyWith(
      clockOut: now,
      clockOutLat: position?.latitude ?? entry.clockOutLat,
      clockOutLng: position?.longitude ?? entry.clockOutLng,
      updatedAt: now,
    );

    final result = await updateEntryUseCase.call(updated);
    if (result.success && result.data != null) {
      currentEntry.value = null;
      _clockTimer?.cancel();
      currentDuration.value = Duration.zero;

      final idx = todayEntries.indexWhere((e) => e.id == updated.id);
      if (idx != -1) {
        todayEntries[idx] = updated;
      }

      _recomputeScheduleCounter();
    } else {
      Get.snackbar('Error', 'No se pudo registrar la salida');
    }
  }

  Future<void> clockIn() async {
    if (currentEntry.value != null) {
      Get.snackbar('Aviso', 'Ya hay una entrada activa');
      return;
    }

    final employee = brain.employee.value;
    if (employee == null) {
      Get.snackbar('Error', 'No se encontró el empleado en sesión');
      return;
    }

    final now = DateTime.now();
    final position = await _getSafePosition();

    final newEntry = ClockInOutModel(
      id: const Uuid().v4(),
      employeeId: employee.uid,
      companyId: employee.companyId,
      clockIn: now,
      clockOut: null,
      clockInLat: position?.latitude,
      clockInLng: position?.longitude,
      clockOutLat: null,
      clockOutLng: null,
      createdAt: now,
      updatedAt: now,
      isEdited: false,
      editedFields: [],
    );

    final result = await createEntryUseCase.call(newEntry);
    if (result.success && result.data != null) {
      currentEntry.value = result.data;
      todayEntries.insert(0, result.data!);
      _startClockTimer();

      _recomputeScheduleCounter();
    } else {
      Get.snackbar('Error', 'No se pudo registrar la entrada');
    }
  }

  Duration getTotalWorkedToday() {
    return todayEntries.fold(Duration.zero, (sum, entry) {
      if (entry.clockOut != null) {
        return sum + entry.clockOut!.difference(entry.clockIn);
      }
      return sum;
    });
  }

  String getFormattedWorkedToday() {
    final duration = getTotalWorkedToday();
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes.toString().padLeft(2, '0')}min';
  }
}