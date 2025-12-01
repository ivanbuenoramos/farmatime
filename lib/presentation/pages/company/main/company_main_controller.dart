import 'package:farmatime/core/routes/routes.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/presentation/pages/company/main/widgets/subscription_payment_issue_modal.dart';



class CompanyMainController extends GetxController {
  
  final Brain brain = Get.find<Brain>();

  final RxInt indexTab = 0.obs;

  @override
  void onReady() {
    super.onReady();
    if (brain.company.value?.verifiedEmail == false) {
      // Future.microtask(() {
      //   Get.offNamed(Routes.companyAuthVerifyEmail, arguments: {
      //     'companyId': brain.company.value?.id,
      //     'company': brain.company.value,
      //   });
      // });
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

  Future<void> showSubscriptionPaymentIssueModal() async {
    Get.bottomSheet(
      SubscriptionPaymentIssueModalContent(),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }


}
