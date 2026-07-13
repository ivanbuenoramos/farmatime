import 'package:farmatime/data/repositories/shift_template_repository_impl.dart';
import 'package:farmatime/domain/repositories/shift_template_repository.dart';
import 'package:farmatime/domain/usecases/employee_schedule/delete_recurring_rule_usecase.dart';
import 'package:farmatime/domain/usecases/employee_schedule/upsert_recurring_rule_usecase.dart';
import 'package:farmatime/domain/usecases/shift_template/list_shift_templates_usecase.dart';
import 'package:farmatime/domain/usecases/shift_template/upsert_shift_template_usecase.dart';
import 'package:get/get.dart';

import 'package:farmatime/domain/repositories/employee_schedule_repository.dart';
import 'package:farmatime/data/repositories/employee_schedule_repository_impl.dart';
import 'package:farmatime/domain/usecases/employee_schedule/list_recurring_rules_usecase.dart';
import 'package:farmatime/domain/usecases/employee_schedule/get_employee_month_schedule_usecase.dart';
import 'package:farmatime/domain/usecases/employee_schedule/get_assigned_days_in_year_usecase.dart';
import 'package:farmatime/domain/usecases/employee_schedule/upsert_employee_month_schedule_usecase.dart';
import 'package:farmatime/presentation/pages/company/schedule/company_employee_schedule_controller.dart';

class EmployeeScheduleBinding extends Bindings {

  @override
  void dependencies() {
    // Repo
    Get.lazyPut<EmployeeScheduleRepository>(() => EmployeeScheduleRepositoryImpl());

    Get.lazyPut<ShiftTemplateRepository>(() => ShiftTemplateRepositoryImpl());

    // UseCases
    Get.lazyPut<GetEmployeeMonthScheduleUseCase>(
      () => GetEmployeeMonthScheduleUseCase(Get.find<EmployeeScheduleRepository>()),
    );
    Get.lazyPut<GetAssignedDaysInYearUseCase>(
      () => GetAssignedDaysInYearUseCase(Get.find<EmployeeScheduleRepository>()),
    );
    Get.lazyPut<UpsertEmployeeMonthScheduleUseCase>(
      () => UpsertEmployeeMonthScheduleUseCase(Get.find<EmployeeScheduleRepository>()),
    );
    Get.lazyPut<ListRecurringRulesUseCase>(
      () => ListRecurringRulesUseCase(Get.find<EmployeeScheduleRepository>()),
    );
    Get.lazyPut<UpsertRecurringShiftRuleUseCase>(
      () => UpsertRecurringShiftRuleUseCase(Get.find<EmployeeScheduleRepository>()),
    );
    Get.lazyPut<DeleteRecurringShiftRuleUseCase>(
      () => DeleteRecurringShiftRuleUseCase(Get.find<EmployeeScheduleRepository>()),
    );
    Get.lazyPut<ListShiftTemplatesUseCase>(
      () => ListShiftTemplatesUseCase(Get.find<ShiftTemplateRepository>()),
    );

    Get.lazyPut<UpsertShiftTemplateUseCase>(
      () => UpsertShiftTemplateUseCase(Get.find<ShiftTemplateRepository>()),
    );

    // Controller
    Get.lazyPut<EmployeeScheduleController>(() => EmployeeScheduleController(
          getMonthUC: Get.find<GetEmployeeMonthScheduleUseCase>(),
          upsertMonthUC: Get.find<UpsertEmployeeMonthScheduleUseCase>(),
          listRulesUC: Get.find<ListRecurringRulesUseCase>(),
          getAssignedDaysUC: Get.find<GetAssignedDaysInYearUseCase>(),
        ));
  }
}
