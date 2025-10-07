import 'package:farmatime/presentation/pages/chat/inbox/inbox_page.dart';
import 'package:farmatime/presentation/pages/company/dashboard/company_dashboard_page.dart';
import 'package:farmatime/presentation/pages/company/employees/company_employees_page.dart';
import 'package:farmatime/presentation/pages/company/entries/company_entries_page.dart';
import 'package:farmatime/presentation/pages/company/profile/company_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import 'package:get/get.dart';

import 'package:farmatime/presentation/pages/company/main/company_main_controller.dart';



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
              CompanyProfilePage(),
            ],
          ),
        )
      ),
    );
  }

  final List<BottomNavigationBarItem> items = [

    BottomNavigationBarItem(
      icon: SvgPicture.asset('assets/icons/home.svg', height: 26),
      activeIcon: SvgPicture.asset('assets/icons/home_bold.svg', height: 26),
      label: 'Inicio',
    ),

    BottomNavigationBarItem(
      icon: SvgPicture.asset('assets/icons/documents.svg', height: 26),
      activeIcon: SvgPicture.asset('assets/icons/documents_bold.svg', height: 26),
      label: 'Fichajes',
    ),

    BottomNavigationBarItem(
      icon: SvgPicture.asset('assets/icons/chat.svg', height: 26),
      activeIcon: SvgPicture.asset('assets/icons/chat_bold.svg', height: 26),
      label: 'Chat interno',
    ),

    BottomNavigationBarItem(
      icon: SvgPicture.asset('assets/icons/users.svg', height: 26),
      activeIcon: SvgPicture.asset('assets/icons/users_bold.svg', height: 26),
      label: 'Empleados',
    ),

    BottomNavigationBarItem(
      icon: SvgPicture.asset('assets/icons/pharmacy.svg', height: 26),
      activeIcon: SvgPicture.asset('assets/icons/pharmacy_bold.svg', height: 26),
      label: 'Perfil',
    ),
  ];

  Widget _bottomNavBar(context, controller) {
    return Obx(() => Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Get.theme.colorScheme.outline,
            width: 0.5,
          ),
        ),
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.white,
        showSelectedLabels: false,
        showUnselectedLabels: false,
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
