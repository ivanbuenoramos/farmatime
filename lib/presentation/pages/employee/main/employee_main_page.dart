
import 'package:farmatime/presentation/pages/employee/calendar/employee_calendar_page.dart';
import 'package:farmatime/presentation/pages/employee/entries/employee_entries_page.dart';
import 'package:farmatime/presentation/pages/employee/my_day/employee_may_day_page.dart';
import 'package:farmatime/presentation/pages/employee/profile/employee_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import 'package:get/get.dart';

import 'package:farmatime/presentation/pages/company/main/company_main_controller.dart';



class EmployeeMainPage extends StatelessWidget {

  EmployeeMainPage({super.key});

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
              EmployeeMyDayPage(),
              EmployeeEntriesPage(),
              EmployeeCalendarPage(),
              EmployeeProfilePage(),
            ],
          ),
        )
      ),
    );
  }

  final List<BottomNavigationBarItem> items = [

    BottomNavigationBarItem(
      icon: SvgPicture.asset('assets/icons/clock.svg', height: 26),
      activeIcon: SvgPicture.asset('assets/icons/clock_bold.svg', height: 26),
      label: 'Mi día',
    ),

    BottomNavigationBarItem(
      icon: SvgPicture.asset('assets/icons/documents.svg', height: 26),
      activeIcon: SvgPicture.asset('assets/icons/documents_bold.svg', height: 26),
      label: 'Fichajes',
    ),

    BottomNavigationBarItem(
      icon: SvgPicture.asset('assets/icons/calendar.svg', height: 26),
      activeIcon: SvgPicture.asset('assets/icons/calendar_bold.svg', height: 26),
      label: 'Calendario',
    ),

    BottomNavigationBarItem(
      icon: SvgPicture.asset('assets/icons/profile.svg', height: 26),
      activeIcon: SvgPicture.asset('assets/icons/profile_bold.svg', height: 26),
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
