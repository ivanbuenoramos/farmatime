import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:farmatime/core/theme/theme.dart';
import 'package:farmatime/core/routes/routes.dart';
import 'package:toastification/toastification.dart';
import 'package:farmatime/core/routes/app_routes.dart';



class FarmatimeApp extends StatelessWidget {

  const FarmatimeApp({super.key});

  @override
  Widget build(BuildContext context) {

    return ToastificationWrapper(
      child: GestureDetector(
        onTap: () {
          FocusScopeNode currentFocus = FocusScope.of(context);
          if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
            FocusManager.instance.primaryFocus?.unfocus();
          }
        },
        child: GetMaterialApp(
          localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            localeResolutionCallback: (locale, supportedLocales) {
              for (var supportedLocale in supportedLocales) {
                if (supportedLocale.languageCode == locale?.languageCode) {
                  return supportedLocale;
                }
              }
              return supportedLocales.first;
            },
          debugShowCheckedModeBanner: false,
          title: 'FarmaTime',
          getPages: AppRoutes.pages,
          initialRoute: Routes.splash,
          theme: FarmatimeTheme.main,
        ),
      ),
    );
  }
}