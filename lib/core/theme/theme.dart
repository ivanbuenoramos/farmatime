import 'package:flutter/material.dart';

class FarmatimeTheme {
  static ThemeData main = ThemeData(
    brightness: Brightness.light,
    colorScheme: const ColorScheme(
      primary: Color(0xff1971FF),
      onPrimary: Color(0xffFFFFFF),
      secondary: Color(0xff373737),
      onSecondary: Color(0xffFFFFFF),
      tertiary: Color(0xffA5A5A5),
      brightness: Brightness.light,
      error: Color(0xffFF0004),
      onError: Color(0xffFFFFFF),
      surface: Color(0xffFFFFFF),
      onSurface: Color(0xff1971FF),
      outline: Color(0xffE5E5E5),
      background: Color(0xffF5F5F8)
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xff1971FF),
      centerTitle: false,
      iconTheme: IconThemeData(
        color: Color(0xffFFFFFF),
      ),
      titleTextStyle: TextStyle(
        fontSize: 18,
        color: Color(0xffFFFFFF),
        fontWeight: FontWeight.w700,
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      rangeSelectionBackgroundColor: Color(0xff1971FF).withAlpha(50)
    ),
    buttonTheme: const ButtonThemeData(
      splashColor: Colors.transparent,
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        textStyle: WidgetStateProperty.resolveWith<TextStyle?>(
          (Set<WidgetState> states) {
            return const TextStyle(
              fontFamily: 'Circular Std',
              fontSize: 16.0,
              color: Color(0xffFFFFFF),
              fontWeight: FontWeight.w600,
            );
          },
        ),
        overlayColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.pressed)) return null;
            return null;
          },
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(
      thickness: 1,
      color: Color(0xffE5E5E5),
    ),
    splashFactory: NoSplash.splashFactory,
    scaffoldBackgroundColor: const Color(0xffF5F5F8),
    fontFamily: 'Poppins',
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 30,
        color: Color(0xff373737),
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 20,
        letterSpacing: -0.3,
        color: Color(0xff373737),
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        letterSpacing: -0.3,
        color: Color(0xff373737),
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Inter',
        color: Color(0xffA5A5A5),
        letterSpacing: -0.3,
        fontWeight: FontWeight.w500,
        fontSize: 18.0,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Inter',
        color: Color(0xffA5A5A5),
        fontWeight: FontWeight.w500,
        letterSpacing: -0.3,
        fontSize: 16.0,
      ),
      bodySmall: TextStyle(
        fontFamily: 'Inter',
        color: Color(0xffA5A5A5),
        letterSpacing: -0.3,
        fontWeight: FontWeight.w500,
        fontSize: 14.0,
      ),
    ),
  );
}