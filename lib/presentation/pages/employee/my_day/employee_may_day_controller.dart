import 'dart:async';

import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/clock_in_out_model.dart';
import 'package:farmatime/domain/usecases/clock/create_entry_usecase.dart';
import 'package:farmatime/domain/usecases/clock/get_current_entry_usecase.dart';
import 'package:farmatime/domain/usecases/clock/update_entry_usecase.dart';
import 'package:farmatime/domain/usecases/clock/get_entries_by_employee_usecase.dart';

class EmployeeMyDayController extends GetxController {
  final CreateEntryUseCase createEntryUseCase;
  final UpdateEntryUseCase updateEntryUseCase;
  final GetCurrentEntryUseCase getCurrentEntryUseCase;
  final GetEntriesByEmployeeUseCase getEntriesByEmployeeUseCase;

  EmployeeMyDayController({
    required this.createEntryUseCase,
    required this.updateEntryUseCase,
    required this.getCurrentEntryUseCase,
    required this.getEntriesByEmployeeUseCase,
  });

  final Brain brain = Get.find<Brain>();

  final currentEntry = Rxn<ClockInOutModel>();
  final todayEntries = <ClockInOutModel>[].obs;
  final isLoading = false.obs;

  Timer? _clockTimer;
  final currentDuration = Rx<Duration>(Duration.zero);

  @override
  void onInit() {
    super.onInit();
    _loadInitialData();
  }

  @override
  void onClose() {
    _clockTimer?.cancel();
    super.onClose();
  }

  Future<void> _loadInitialData() async {
    isLoading.value = true;
    final employeeId = brain.employee.value?.uid;
    if (employeeId == null) {
      isLoading.value = false;
      return;
    }

    final allEntriesResult = await getEntriesByEmployeeUseCase.call(employeeId);

    if (allEntriesResult.success) {
      final all = List<ClockInOutModel>.from(allEntriesResult.data)
        ..sort((a, b) => b.clockIn.compareTo(a.clockIn)); // ↓ más reciente primero

      if (all.isNotEmpty && all.first.clockOut == null) {
        currentEntry.value = all.first;
        _startClockTimer();
      } else {
        currentEntry.value = null;
        _clockTimer?.cancel();
        currentDuration.value = Duration.zero;
      }

      final today = DateTime.now();
      todayEntries.assignAll(
        all.where(
          (e) =>
              e.clockIn.year == today.year &&
              e.clockIn.month == today.month &&
              e.clockIn.day == today.day,
        ),
      );
    } else {
      Get.snackbar('Error', 'No se pudieron cargar fichajes');
    }

    isLoading.value = false;
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

  /// Lee la ubicación de forma segura.
  /// Si falla, devuelve `null` y deja seguir el fichaje sin ubicación.
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
    } catch (e) {
      Get.snackbar('Error ubicación', 'No se pudo obtener la ubicación.');
      return null;
    }
  }

  Future<void> clockOut() async {
    final entry = currentEntry.value;
    if (entry == null) return;

    final now = DateTime.now();
    final position = await _getSafePosition(); // 👈 intentamos leer ubicación

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
    } else {
      Get.snackbar('Error', 'No se pudo registrar la salida');
    }
  }

  Duration getTotalWorkedToday() {
    return todayEntries.fold(Duration.zero, (sum, entry) {
      if (entry.clockOut != null) {
        return sum + entry.clockOut!.difference(entry.clockIn);
      } else {
        return sum;
      }
    });
  }

  String getFormattedWorkedToday() {
    final duration = getTotalWorkedToday();
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes.toString().padLeft(2, '0')}min';
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
    final position = await _getSafePosition(); // 👈 intentamos leer ubicación

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
    } else {
      Get.snackbar('Error', 'No se pudo registrar la entrada');
    }
  }

  String getTimeSinceLastClockIn() {
    final clockIn = currentEntry.value?.clockIn;
    if (clockIn == null) return '—';
    final duration = DateTime.now().difference(clockIn);
    return duration.toString().split('.').first; // hh:mm:ss
  }
}