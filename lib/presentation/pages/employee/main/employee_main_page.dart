import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:flutter_svg/svg.dart';

import 'package:farmatime/presentation/presentation.dart';
import 'package:farmatime/presentation/pages/chat/inbox/inbox_page.dart';
import 'package:farmatime/presentation/pages/employee/my_day/employee_may_day_page.dart';
import 'package:farmatime/presentation/pages/employee/entries/employee_entries_page.dart';



class EmployeeMainPage extends StatelessWidget {

  EmployeeMainPage({super.key});

  @override
  Widget build(BuildContext context) {
    final EmployeeMainController controller = Get.find<EmployeeMainController>();

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
              InboxPage(),
              EmployeeCalendarPage(),
              EmployeeAccountPage(),
            ],
          ),
        )
      ),
    );
  }

  final List<BottomNavigationBarItem> items = [

    BottomNavigationBarItem(
      icon: SvgPicture.asset(
        'assets/icons/clock.svg', 
        height: 26,
        colorFilter: ColorFilter.mode(
          Get.theme.colorScheme.tertiary,
          BlendMode.srcIn,
        ),
      ),
      activeIcon: SvgPicture.asset(
        'assets/icons/clock_bold.svg',
        height: 26,
        colorFilter: ColorFilter.mode(
          Get.theme.colorScheme.primary,
          BlendMode.srcIn,
        ),
      ),
      label: 'Mi día',
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
        height: 26,
        colorFilter: ColorFilter.mode(
          Get.theme.colorScheme.primary,
          BlendMode.srcIn,
        ),
      ),
      label: 'Chat',
    ),

    BottomNavigationBarItem(
      icon: SvgPicture.asset(
        'assets/icons/calendar.svg', 
        height: 26,
        colorFilter: ColorFilter.mode(
          Get.theme.colorScheme.tertiary,
          BlendMode.srcIn,
        ),
      ),
      activeIcon: SvgPicture.asset(
        'assets/icons/calendar_bold.svg', 
        height: 26,
        colorFilter: ColorFilter.mode(
          Get.theme.colorScheme.primary,
          BlendMode.srcIn,
        ),
      ),
      label: 'Calendario',
    ),

    BottomNavigationBarItem(
      icon: SvgPicture.asset(
        'assets/icons/profile.svg', 
        height: 26,
        colorFilter: ColorFilter.mode(
          Get.theme.colorScheme.tertiary,
          BlendMode.srcIn,
        ),
      ),
      activeIcon: SvgPicture.asset(
        'assets/icons/profile_bold.svg', 
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
