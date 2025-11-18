import 'package:farmatime/presentation/pages/chat/inbox/inbox_page.dart';
import 'package:farmatime/presentation/pages/company/dashboard/company_dashboard_page.dart';
import 'package:farmatime/presentation/pages/company/employees/company_employees_page.dart';
import 'package:farmatime/presentation/pages/company/entries/company_entries_page.dart';
import 'package:farmatime/presentation/pages/company/main/widgets/subscription_payment_issue_modal.dart';
import 'package:farmatime/presentation/presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import 'package:get/get.dart';



class CompanyMainPage extends StatelessWidget {
  CompanyMainPage({super.key});

  @override
  Widget build(BuildContext context) {
    final CompanyMainController controller = Get.find<CompanyMainController>();

    return WillPopScope(
      onWillPop: () async {
        return false;
      },
      child: Obx(() => Scaffold(
        resizeToAvoidBottomInset: false,
          bottomNavigationBar: _bottomNavBar(context, controller),
          body: IndexedStack(
            index: controller.indexTab.value,
            children: [
              CompanyDashboardPage(),
              CompanyEntriesPage(),
              InboxPage(),
              CompanyEmployeesPage(),
              CompanyAccountPage(),
            ],
          ),
        )
      ),
    );
  }

  final List<BottomNavigationBarItem> items = [

    BottomNavigationBarItem(
      icon: SvgPicture.asset(
        'assets/icons/home.svg',
        height: 26,
        colorFilter: ColorFilter.mode(
          Get.theme.colorScheme.tertiary,
          BlendMode.srcIn,
        ),
      ),
      activeIcon: SvgPicture.asset(
        'assets/icons/home_bold.svg',
        height: 26,
        colorFilter: ColorFilter.mode(
          Get.theme.colorScheme.primary,
          BlendMode.srcIn,
        ),
      ),
      label: 'Inicio',
    ),

    BottomNavigationBarItem(
      icon: SvgPicture.asset(
        'assets/icons/documents.svg',
        height: 26,
        colorFilter: ColorFilter.mode(
          Get.theme.colorScheme.tertiary,
          BlendMode.srcIn,
        ),
      ),
      activeIcon: SvgPicture.asset(
        'assets/icons/documents_bold.svg',
        height: 26,
        colorFilter: ColorFilter.mode(
          Get.theme.colorScheme.primary,
          BlendMode.srcIn,
        ),
      ),
      label: 'Fichajes',
    ),

    BottomNavigationBarItem(
      icon: SvgPicture.asset(
        'assets/icons/chat.svg', 
        height: 26,
        colorFilter: ColorFilter.mode(
          Get.theme.colorScheme.tertiary,
          BlendMode.srcIn,
        ),
      ),
      activeIcon: SvgPicture.asset(
        'assets/icons/chat_bold.svg',
        colorFilter: ColorFilter.mode(
          Get.theme.colorScheme.primary,
          BlendMode.srcIn,
        ),
        height: 26,
      ),
      label: 'Chat',
    ),

    BottomNavigationBarItem(
      icon: SvgPicture.asset(
        'assets/icons/users.svg', 
        height: 26,
        colorFilter: ColorFilter.mode(
          Get.theme.colorScheme.tertiary,
          BlendMode.srcIn,
        ),
      ),
      activeIcon: SvgPicture.asset(
        'assets/icons/users_bold.svg',
        height: 26,
        colorFilter: ColorFilter.mode(
          Get.theme.colorScheme.primary,
          BlendMode.srcIn,
        ),
      ),
      label: 'Empleados',
    ),

    BottomNavigationBarItem(
      icon: SvgPicture.asset(
        'assets/icons/pharmacy.svg', 
        height: 26,
        colorFilter: ColorFilter.mode(
          Get.theme.colorScheme.tertiary,
          BlendMode.srcIn,
        ),
      ),
      activeIcon: SvgPicture.asset(
        'assets/icons/pharmacy_bold.svg',
        height: 26,
        colorFilter: ColorFilter.mode(
          Get.theme.colorScheme.primary,
          BlendMode.srcIn,
        ),
      ),
      label: 'Perfil',
    ),
  ];

  Widget _bottomNavBar(context, controller) {
    return Obx(() => Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
          ),
        ],
        border: Border(
          top: BorderSide(
            color: Get.theme.colorScheme.outline,
            width: 1,
          ),
        ),
      ),
      child: BottomNavigationBar(
        backgroundColor: Get.theme.colorScheme.surface,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        onTap: (index) {
          controller.indexTab.value = index;
        },
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontSize: 12),
        enableFeedback: false,
        iconSize: 22,
        elevation: 0,
        currentIndex: controller.indexTab.value,
        items: items,
      ),
    ));
  }
}
