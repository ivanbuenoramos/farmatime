import 'dart:async';

import 'package:farmatime/data/models/employee_shift_model.dart';
import 'package:farmatime/domain/usecases/employee_schedule/get_expected_shift_usecase.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/services/toast_service.dart';
import 'package:farmatime/data/models/clock_in_out_model.dart';
import 'package:farmatime/data/models/clock_audit_log_model.dart';
import 'package:farmatime/domain/usecases/clock/create_entry_usecase.dart';
import 'package:farmatime/domain/usecases/clock/update_entry_usecase.dart';
import 'package:farmatime/domain/usecases/clock/get_entries_by_employee_usecase.dart';
import 'package:farmatime/domain/usecases/clock/log_clock_creation_usecase.dart';

class EmployeeMyDayController extends GetxController {
  final CreateEntryUseCase createEntryUseCase;
  final UpdateEntryUseCase updateEntryUseCase;
  final GetEntriesByEmployeeUseCase getEntriesByEmployeeUseCase;
  final GetExpectedShiftsForDayUseCase getExpectedShiftUseCase;
  final LogClockCreationUseCase logClockCreationUseCase;

  EmployeeMyDayController({
    required this.createEntryUseCase,
    required this.updateEntryUseCase,
    required this.getEntriesByEmployeeUseCase,
    required this.getExpectedShiftUseCase,
    required this.logClockCreationUseCase,
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
      ToastService().show(
        title: 'Error',
        message: 'No se pudieron cargar fichajes',
        type: ToastType.error,
      );
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

    final result = await getExpectedShiftUseCase.call(
      companyId: employee.companyId,
      employeeIds: [employee.uid],
      dayDate: dayDate,
    );

    if (result.success) {
      todayExpected.value = result.data[employee.uid]; // null = no trabaja hoy
    } else {
      todayExpected.value = null;
    }
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
        ToastService().show(
          title: 'Ubicación desactivada',
          message:
              'Activa la ubicación del dispositivo para registrar dónde fichas.',
          type: ToastType.warning,
        );
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ToastService().show(
            title: 'Permiso denegado',
            message:
                'No se ha concedido permiso de ubicación. Se registrará el fichaje sin ubicación.',
            type: ToastType.warning,
          );
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ToastService().show(
          title: 'Permiso bloqueado',
          message:
              'Los permisos de ubicación están bloqueados. Actívalos en ajustes para registrar la ubicación.',
          type: ToastType.warning,
        );
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      ToastService().show(
        title: 'Error ubicación',
        message: 'No se pudo obtener la ubicación.',
        type: ToastType.error,
      );
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
      ToastService().show(
        title: 'Error',
        message: 'No se pudo registrar la salida',
        type: ToastType.error,
      );
    }
  }

  Future<void> clockIn() async {
    if (currentEntry.value != null) {
      ToastService().show(
        title: 'Aviso',
        message: 'Ya hay una entrada activa',
        type: ToastType.warning,
      );
      return;
    }

    final employee = brain.employee.value;
    if (employee == null) {
      ToastService().show(
        title: 'Error',
        message: 'No se encontró el empleado en sesión',
        type: ToastType.error,
      );
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

      // Registro inmutable del estado inicial del fichaje (trazabilidad).
      // Best-effort: no bloquea el fichaje si falla.
      logClockCreationUseCase(
        ClockAuditLogModel(
          id: const Uuid().v4(),
          entryId: newEntry.id,
          companyId: newEntry.companyId,
          employeeId: newEntry.employeeId,
          action: ClockAuditAction.created,
          actorUid: employee.uid,
          actorRole: 'employee',
          actorName: employee.name,
          reason: null,
          changes: const [],
          at: now,
        ),
      );

      _recomputeScheduleCounter();
    } else {
      ToastService().show(
        title: 'Error',
        message: 'No se pudo registrar la entrada',
        type: ToastType.error,
      );
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

  /// Tiempo total trabajado hoy incluyendo el turno en curso (si lo hay).
  /// Reactivo: depende de [currentDuration], que se refresca cada segundo.
  Duration get totalWorkedTodayLive {
    var sum = getTotalWorkedToday();
    final active = currentEntry.value;
    if (active != null && active.clockOut == null) {
      sum += currentDuration.value;
    }
    return sum;
  }

  String formatDurationHm(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes.toString().padLeft(2, '0')}min';
  }

  String getFormattedWorkedToday() => formatDurationHm(getTotalWorkedToday());

  /// Nº de fichajes (turnos) registrados hoy.
  int get todayShiftCount => todayEntries.length;
}