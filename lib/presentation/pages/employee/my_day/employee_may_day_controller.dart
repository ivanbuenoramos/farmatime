import 'dart:async';

import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

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
    if (employeeId == null) return;

    /// 1. Cargamos TODOS los fichajes del empleado (ordenados ↓)
    final allEntriesResult = await getEntriesByEmployeeUseCase.call(employeeId);

    if (allEntriesResult.success) {
      final all = List<ClockInOutModel>.from(allEntriesResult.data)
        ..sort((a, b) => b.clockIn.compareTo(a.clockIn)); // ↓ más reciente primero

      /// 2. El primero marca si hay entrada activa
      if (all.isNotEmpty && all.first.clockOut == null) {
        currentEntry.value = all.first;
        _startClockTimer();
      } else {
        currentEntry.value = null;
        _clockTimer?.cancel();
        currentDuration.value = Duration.zero;
      }

      /// 3. Solo los de hoy para la tarjeta “Fichajes de hoy”
      final today = DateTime.now();
      todayEntries.assignAll(
        all.where((e) =>
          e.clockIn.year == today.year &&
          e.clockIn.month == today.month &&
          e.clockIn.day == today.day),
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

    // ←  Primer valor inmediatamente
    currentDuration.value = DateTime.now().difference(clockIn);

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      currentDuration.value = DateTime.now().difference(clockIn);
    });
  }



  Future<void> clockOut() async {
    final entry = currentEntry.value;
    if (entry == null) return;

    final updated = entry.copyWith(
      clockOut: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final result = await updateEntryUseCase.call(updated);
    if (result.success && result.data != null) {
      currentEntry.value = null;
      _clockTimer?.cancel();             // detener cronómetro
      currentDuration.value = Duration.zero;
      final idx = todayEntries.indexWhere((e) => e.id == updated.id);
      if (idx != -1) todayEntries[idx] = updated;
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
    final now = DateTime.now();

    final newEntry = ClockInOutModel(
      id: const Uuid().v4(),
      employeeId: employee!.uid,
      companyId: employee.companyId,
      clockIn: now,
      clockOut: null,
      notes: null,
      createdAt: now,
      updatedAt: now,
    );

    final result = await createEntryUseCase.call(newEntry);
    if (result.success && result.data != null) {
      currentEntry.value = result.data;
      todayEntries.insert(0, result.data!);
      _startClockTimer();                     // ← aquí
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
