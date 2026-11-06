import 'package:flutter/material.dart';

import 'design_tokens.dart';

abstract final class BrainyTheme {
  static final light = ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
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
        backgroundColor: const Color(0xFF2463CE),
        foregroundColor: const Color(0xFFFFFFFF),
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        side: const BorderSide(color: Color(0xFF778293)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFFFFFFFF),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: TextStyle(color: Color(0xFF545E6D)),
      floatingLabelStyle: TextStyle(color: Color(0xFF2463CE)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: Color(0xFF778293)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: Color(0xFF2463CE), width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
  static final dark = ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
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
        backgroundColor: BrainyColors.darkAccent,
        foregroundColor: BrainyColors.darkOnAccent,
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
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: BrainyColors.darkSurface,
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: TextStyle(color: BrainyColors.darkMuted),
      floatingLabelStyle: TextStyle(color: BrainyColors.darkAccent),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: BrainyColors.darkControl),
      ),
      focusedBorder: OutlineInputBorder(
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
