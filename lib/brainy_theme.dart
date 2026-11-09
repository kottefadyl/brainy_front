import 'package:flutter/material.dart';

import 'design_tokens.dart';

abstract final class BrainyTheme {
  static final light = ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    colorScheme: ColorScheme.fromSeed(
      seedColor: BrainyColors.blue,
      primary: BrainyColors.blue,
      onPrimary: const Color(0xFFFFFFFF),
      surface: BrainyColors.lightSurface,
      onSurface: BrainyColors.lightInk,
      error: const Color(0xFFB42332),
    ),
    scaffoldBackgroundColor: BrainyColors.lightCanvas,
    dialogTheme: DialogThemeData(
      backgroundColor: BrainyColors.lightSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: BrainyColors.blue,
        foregroundColor: const Color(0xFFFFFFFF),
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        side: const BorderSide(color: BrainyColors.lightControl),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      floatingLabelBehavior: FloatingLabelBehavior.always,
      alignLabelWithHint: true,
      helperMaxLines: 2,
      errorMaxLines: 3,
      filled: true,
      fillColor: Color(0xFFFFFFFF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: const TextStyle(color: BrainyColors.lightMuted),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) => TextStyle(color: states.contains(WidgetState.error) ? const Color(0xFFB42332) : states.contains(WidgetState.focused) ? BrainyColors.blue : BrainyColors.lightMuted, fontWeight: FontWeight.w500)),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: BrainyColors.lightControl),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: BrainyColors.blue, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
  static final dark = ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    colorScheme: ColorScheme.fromSeed(
      seedColor: BrainyColors.darkAccent,
      brightness: Brightness.dark,
      primary: BrainyColors.darkAccent,
      onPrimary: BrainyColors.darkOnAccent,
      surface: BrainyColors.darkSurface,
      onSurface: BrainyColors.darkInk,
      error: const Color(0xFFFFADB5),
    ),
    scaffoldBackgroundColor: BrainyColors.darkCanvas,
    dialogTheme: DialogThemeData(
      backgroundColor: BrainyColors.darkElevated,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: BrainyColors.darkPrimary,
        foregroundColor: const Color(0xFFFFFFFF),
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        side: const BorderSide(color: BrainyColors.darkControl),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      floatingLabelBehavior: FloatingLabelBehavior.always,
      alignLabelWithHint: true,
      helperMaxLines: 2,
      errorMaxLines: 3,
      filled: true,
      fillColor: BrainyColors.darkSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: const TextStyle(color: BrainyColors.darkMuted),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) => TextStyle(color: states.contains(WidgetState.error) ? const Color(0xFFFFADB5) : states.contains(WidgetState.focused) ? BrainyColors.darkAccent : BrainyColors.darkMuted, fontWeight: FontWeight.w500)),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: BrainyColors.darkControl),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: BrainyColors.darkAccent, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
