import 'package:get/get.dart';

import 'package:collection/collection.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/domain/usecases/clock/get_entries_by_employee_usecase.dart';

class EmployeeEntriesController extends GetxController {
  final GetEntriesByEmployeeUseCase getEntriesByEmployeeUseCase;

  EmployeeEntriesController({required this.getEntriesByEmployeeUseCase});

  final Brain brain = Get.find<Brain>();

  final groupedClockIns = <DateTime, List<_ClockInOutDisplay>>{}.obs;

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  Future<void> fetch() async {
    final result = await getEntriesByEmployeeUseCase.call(brain.employee.value?.uid ?? '');
    if (result.success) {
      final allItems = <_ClockInOutDisplay>[];
      for (final model in result.data) {
        allItems.add(_ClockInOutDisplay(
          time: model.clockIn,
          type: ClockInOutType.entry,
        ));
        if (model.clockOut != null) {
          allItems.add(_ClockInOutDisplay(
            time: model.clockOut!,
            type: ClockInOutType.exit,
          ));
        }
      }
      allItems.sort((a, b) => b.time.compareTo(a.time));
      groupedClockIns.value = groupBy(allItems, (e) => DateTime(e.time.year, e.time.month, e.time.day));
    } else {
      Get.snackbar('Error', 'No se pudieron cargar los registros de entrada');
    }
  }
}

enum ClockInOutType { entry, exit }

class _ClockInOutDisplay {
  final DateTime time;
  final ClockInOutType type;

  _ClockInOutDisplay({required this.time, required this.type});
}