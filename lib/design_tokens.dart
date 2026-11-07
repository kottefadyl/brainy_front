import 'package:flutter/material.dart';

/// Shared surfaces for the web-aligned Brainy workspace.
abstract final class BrainyColors {
  static const lightCanvas = Color(0xFFF3F6FB);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightInk = Color(0xFF17263A);
  static const lightMuted = Color(0xFF52647C);
  static const lightLine = Color(0xFFD7E1ED);
  static const navigationBlue = Color(0xFF084BC4);
  static const lightSidebar = navigationBlue;
  static const lightHero = navigationBlue;
  static const blue = Color(0xFF2463CE);

  static const darkCanvas = Color(0xFF19191B);
  static const darkSurface = Color(0xFF242427);
  static const darkElevated = Color(0xFF2F2F33);
  static const darkInk = Color(0xFFF2F2F4);
  static const darkMuted = Color(0xFFBFC0C6);
  static const darkLine = Color(0xFF49494F);
  static const darkControl = Color(0xFF85858E);
  static const darkSidebar = navigationBlue;
  static const darkHero = navigationBlue;
  static const darkAccent = Color(0xFF96BDFF);
  static const darkAccentSoft = Color(0xFF263A59);
  static const darkOnAccent = Color(0xFF142443);

  static const brandRed = Color(0xFFF1919D);
  static const lightControl = Color(0xFF778293);
}

/// Deeper-blue surfaces and contrasting text, shared by navigation and the banner.
abstract final class BrainyNavigationColors {
  static Color ink(bool dark) => const Color(0xFFFFFFFF);
  static Color muted(bool dark) => const Color(0xFFF4F8FF);
  static Color field(bool dark) => const Color(0xFF0641AD);
  static Color selected(bool dark) => const Color(0xFF06378F);
  static Color border(bool dark) => const Color(0xFFD0E0FF);
}
