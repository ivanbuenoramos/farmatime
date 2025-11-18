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
      outline: Color(0xffE5E5E5)
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xff1971FF),
      titleSpacing: 0,
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
    cardTheme: CardThemeData(
      color: Color(0xffFFFFFF),
      elevation: 2,
      shadowColor: Colors.black12,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xffE5E5E5), width: 1),
      ),
    ),
    dividerColor: const Color(0xffE5E5E5),
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
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all(const Size.fromHeight(44)),
        backgroundColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.disabled)) {
              return const Color(0xffA5A5A5);
            }
            return const Color(0xff1971FF);
          },
        ),
        foregroundColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.disabled)) {
              return const Color(0xffFFFFFF).withAlpha(100);
            }
            return const Color(0xffFFFFFF);
          },
        ),
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
            if (states.contains(WidgetState.pressed)) {
              return const Color(0xffFFFFFF).withAlpha(30);
            }
            return null;
          },
        ),
        shape: WidgetStateProperty.resolveWith<OutlinedBorder?>(
          (Set<WidgetState> states) {
            return RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            );
          },
        ),
        padding: WidgetStateProperty.resolveWith<EdgeInsetsGeometry?>(
          (Set<WidgetState> states) {
            return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
          },
        ),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      tileColor: const Color(0xffFFFFFF),
      textColor: const Color(0xff373737),
      subtitleTextStyle: const TextStyle(
        fontSize: 14,
        color: Color(0xffA5A5A5),
      ),
      titleTextStyle: const TextStyle(
        fontSize: 16,
        color: Color(0xff373737),
        fontWeight: FontWeight.w600,
      ),
      iconColor: const Color(0xff1971FF),
      horizontalTitleGap: 16,
      minLeadingWidth: 0,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xff1971FF),
      foregroundColor: Color(0xffFFFFFF),
      shape: CircleBorder(),
      elevation: 0,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all(const Size.fromHeight(44)),
        side: WidgetStateProperty.resolveWith<BorderSide?>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.disabled)) {
              return const BorderSide(color: Color(0xffE5E5E5), width: 1);
            }
            return const BorderSide(color: Color(0xff1971FF), width: 1);
          },
        ),
        foregroundColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.disabled)) {
              return const Color(0xffA5A5A5);
            }
            return const Color(0xff1971FF);
          },
        ),
        textStyle: WidgetStateProperty.resolveWith<TextStyle?>(
          (Set<WidgetState> states) {
            return const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16.0,
              fontWeight: FontWeight.w600,
            );
          },
        ),
        shape: WidgetStateProperty.resolveWith<OutlinedBorder?>(
          (Set<WidgetState> states) {
            return RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            );
          },
        ),
        overlayColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.pressed)) {
              return Colors.black12;
            }
            return null;
          },
        ),
        padding: WidgetStateProperty.resolveWith<EdgeInsetsGeometry?>(
          (Set<WidgetState> states) {
            return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
          },
        ),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: const Color(0xffFFFFFF),
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: const Color(0xffE5E5E5),
          width: 1,
        ),
      ),
      textStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        color: Color(0xff373737),
        fontWeight: FontWeight.w500,
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        elevation: WidgetStateProperty.all(0),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        color: Color(0xff373737),
        fontWeight: FontWeight.w500,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xffFFFFFF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xffE5E5E5), width: 1),
      ),
      floatingLabelStyle: const TextStyle(
        fontSize: 12,
        color: Color(0xff1971FF),
        fontWeight: FontWeight.w500,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xffE5E5E5), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xff1971FF), width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xffFF0004), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xffFF0004), width: 1),
      ),
      labelStyle: const TextStyle(
        fontSize: 14,
        color: Color(0xffA5A5A5),
        fontWeight: FontWeight.w500,
      ),
      helperStyle: const TextStyle(
        fontSize: 14,
        color: Color(0xffA5A5A5),
        fontWeight: FontWeight.w500,
      ),
      hintStyle: const TextStyle(
        fontSize: 14,
        color: Color(0xffA5A5A5),
        fontWeight: FontWeight.w500,
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