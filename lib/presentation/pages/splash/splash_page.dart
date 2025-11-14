import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:farmatime/presentation/presentation.dart';



class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {

    Get.find<SplashController>();

    return Scaffold(
      backgroundColor: Get.theme.colorScheme.primary,
      body: Center(
        child: Text(
          'farmatime',
          style: Get.theme.textTheme.headlineLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            fontSize: 32,
          ),
        ),
      ),
    );
  }
}
