import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/schedule/time_off_model.dart';
import 'package:farmatime/domain/usecases/time_off/stream_time_off_by_company_usecase.dart';
import 'package:farmatime/domain/usecases/time_off/decide_time_off_usecase.dart';
import 'package:farmatime/domain/usecases/time_off/find_time_off_overlaps_usecase.dart';
import 'package:farmatime/presentation/widgets/time_off/time_off_manage_sheet.dart';

enum TimeOffFilter { pending, history }

class CompanyTimeOffController extends GetxController {
  CompanyTimeOffController({
    required this.streamByCompanyUseCase,
    required this.decideTimeOffUseCase,
    required this.findTimeOffOverlapsUseCase,
  });

  final StreamTimeOffByCompanyUseCase streamByCompanyUseCase;
  final DecideTimeOffUseCase decideTimeOffUseCase;
  final FindTimeOffOverlapsUseCase findTimeOffOverlapsUseCase;

  final Brain brain = Get.find<Brain>();

  final RxList<TimeOffModel> all = <TimeOffModel>[].obs;
  final RxBool isLoading = true.obs;
  final Rx<TimeOffFilter> filter = TimeOffFilter.pending.obs;

  StreamSubscription<List<TimeOffModel>>? _sub;

  String get _companyId => brain.company.value?.id ?? '';
  String get decidedBy => brain.company.value?.id ?? '';

  @override
  void onInit() {
    super.onInit();
    _bind();
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  void _bind() {
    if (_companyId.isEmpty) {
      isLoading.value = false;
      return;
    }
    _sub?.cancel();
    _sub = streamByCompanyUseCase.call(companyId: _companyId).listen((list) {
      all.assignAll(list);
      isLoading.value = false;
    }, onError: (_) {
      isLoading.value = false;
    });
  }

  void setFilter(TimeOffFilter f) => filter.value = f;

  /// Solicitudes que requieren acción de la empresa.
  List<TimeOffModel> get pending =>
      all.where((r) => r.awaitingCompany).toList();

  /// El resto (esperando empleado, aprobadas, rechazadas, canceladas).
  List<TimeOffModel> get history =>
      all.where((r) => !r.awaitingCompany).toList();

  List<TimeOffModel> get visible =>
      filter.value == TimeOffFilter.pending ? pending : history;

  String employeeName(String employeeId) {
    final emp =
        brain.companyEmployees.firstWhereOrNull((e) => e.uid == employeeId);
    return emp?.name ?? 'Empleado';
  }

  Future<void> manage(BuildContext context, TimeOffModel request) async {
    await TimeOffManageSheet.show(
      context,
      request: request,
      employeeName: employeeName(request.employeeId),
      decideUseCase: decideTimeOffUseCase,
      overlapsUseCase: findTimeOffOverlapsUseCase,
      decidedBy: decidedBy,
    );
  }
}
