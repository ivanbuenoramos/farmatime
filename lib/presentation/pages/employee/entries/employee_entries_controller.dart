import 'package:get/get.dart';

import 'package:collection/collection.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/clock_in_out_model.dart';
import 'package:farmatime/domain/usecases/clock/get_entries_by_employee_usecase.dart';

class EmployeeEntriesController extends GetxController {
  final GetEntriesByEmployeeUseCase getEntriesByEmployeeUseCase;

  EmployeeEntriesController({required this.getEntriesByEmployeeUseCase});

  final Brain brain = Get.find<Brain>();

  /// Fichajes (entrada/salida emparejados) agrupados por día, días más
  /// recientes primero y cada día con sus registros ordenados por hora.
  final groupedByDay = <DateTime, List<ClockInOutModel>>{}.obs;

  final isLoading = true.obs;
  final hasError = false.obs;

  String get employeeName => brain.employee.value?.name ?? 'Empleado';
  String? get employeeUid => brain.employee.value?.uid;
  String? get employeePhotoUrl => brain.employee.value?.photoUrl;

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  Future<void> fetch() async {
    isLoading.value = true;
    hasError.value = false;

    final result =
        await getEntriesByEmployeeUseCase.call(brain.employee.value?.uid ?? '');

    if (result.success) {
      final records = [...result.data]
        ..sort((a, b) => b.clockIn.compareTo(a.clockIn));

      final grouped = groupBy<ClockInOutModel, DateTime>(
        records,
        (r) => DateTime(r.clockIn.year, r.clockIn.month, r.clockIn.day),
      );

      // Dentro de cada día, ordenamos por hora ascendente (cronológico).
      for (final list in grouped.values) {
        list.sort((a, b) => a.clockIn.compareTo(b.clockIn));
      }

      groupedByDay.value = grouped;
    } else {
      hasError.value = true;
    }

    isLoading.value = false;
  }

  /// Minutos trabajados en un día. Los turnos sin salida (en curso) cuentan
  /// hasta el momento actual.
  int workedMinutesFor(List<ClockInOutModel> records) {
    final now = DateTime.now();
    return records.fold<int>(0, (prev, r) {
      final end = r.clockOut ?? now;
      final diff = end.difference(r.clockIn).inMinutes;
      return prev + diff.clamp(0, 24 * 60);
    });
  }

  /// True si algún turno del día sigue abierto (sin salida).
  bool hasOpenShift(List<ClockInOutModel> records) =>
      records.any((r) => r.clockOut == null);
}
