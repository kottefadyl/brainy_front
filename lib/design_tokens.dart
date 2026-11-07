import 'package:flutter/material.dart';

/// Shared surfaces for the web-aligned Brainy workspace.
abstract final class BrainyColors {
  static const lightCanvas = Color(0xFFF3F6FB);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightInk = Color(0xFF17263A);
  static const lightMuted = Color(0xFF52647C);
  static const lightLine = Color(0xFFD7E1ED);
  static const lightSidebar = Color(0xFFE0F2FA);
  static const lightHero = Color(0xFFD6EEF9);
  static const blue = Color(0xFF2463CE);

  static const darkCanvas = Color(0xFF19191B);
  static const darkSurface = Color(0xFF242427);
  static const darkElevated = Color(0xFF2F2F33);
  static const darkInk = Color(0xFFF2F2F4);
  static const darkMuted = Color(0xFFBFC0C6);
  static const darkLine = Color(0xFF49494F);
  static const darkControl = Color(0xFF85858E);
  static const darkSidebar = Color(0xFF253E4B);
  static const darkHero = Color(0xFF304F60);
  static const darkAccent = Color(0xFF96BDFF);
  static const darkAccentSoft = Color(0xFF263A59);
  static const darkOnAccent = Color(0xFF142443);

  static const brandRed = Color(0xFFF1919D);
  static const lightControl = Color(0xFF778293);
}

/// Ice-blue surfaces and contrasting text, shared by navigation and the banner.
abstract final class BrainyNavigationColors {
  static Color ink(bool dark) =>
      dark ? const Color(0xFFE3F5FF) : const Color(0xFF21485C);
  static Color muted(bool dark) =>
      dark ? const Color(0xFFBDD9E8) : const Color(0xFF456477);
  static Color field(bool dark) =>
      dark ? const Color(0xFF2D4856) : const Color(0xFFF2FAFF);
  static Color selected(bool dark) =>
      dark ? const Color(0xFF3B5D6D) : const Color(0xFFBDDFED);
  static Color border(bool dark) =>
      dark ? const Color(0xFF88ADBF) : const Color(0xFF628395);
}
