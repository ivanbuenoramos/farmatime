import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/usecases/employee/get_employees_by_company_id_usecase.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/presentation/pages/company/main/widgets/subscription_payment_issue_modal.dart';



class CompanyMainController extends GetxController {

  final GetEmployeesByCompanyIdUseCase getEmployeesByCompanyIdUseCase;

  CompanyMainController({
    required this.getEmployeesByCompanyIdUseCase,
  });
  
  final Brain brain = Get.find<Brain>();

  final RxInt indexTab = 0.obs;

  @override
  void onReady() {
    super.onReady();
    if (brain.company.value?.verifiedEmail == false) {
      Future.microtask(() {
        // Get.offNamed(Routes.companyAuthVerifyEmail, arguments: {
        //   'company': brain.company.value,
        // });
      });
    }

    if (brain.company.value!.billingStatus == 'past_due' ||
        brain.company.value!.billingStatus == 'unpaid') {
      showSubscriptionPaymentIssueModal();
      return;
    } else if (brain.company.value!.billingStatus == 'incomplete') {
      Future.microtask(() {
        Get.toNamed(Routes.companySubscriptionIncompletePayment);
      });
    }
  }

  Future<void> getEmployees() async {

    if (brain.company.value == null) return;

    final Result<List<EmployeeModel>> result = await getEmployeesByCompanyIdUseCase.call(
      companyId: brain.company.value!.id,
      includeDeleted: true
    );

    if (result.success) {
      brain.companyEmployees.assignAll(result.data);
    }
  }

  Future<void> showSubscriptionPaymentIssueModal() async {
    Get.bottomSheet(
      SubscriptionPaymentIssueModalContent(),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }


}
