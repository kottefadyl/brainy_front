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

/// Colors of the analysis chart, the same on the web client.
@immutable
class ChartColors {
  const ChartColors._({
    required this.main,
    required this.comparison,
    required this.ink,
    required this.muted,
    required this.line,
    required this.surface,
    required this.success,
    required this.successSoft,
    required this.danger,
    required this.dangerSoft,
  });

  final Color main, comparison, ink, muted, line, surface;
  final Color success, successSoft, danger, dangerSoft;

  static const _light = ChartColors._(
    main: Color(0xFF2463CE),
    comparison: Color(0xFF0F8F72),
    ink: BrainyColors.lightInk,
    muted: BrainyColors.lightMuted,
    line: BrainyColors.lightLine,
    surface: BrainyColors.lightSurface,
    success: Color(0xFF157F3B),
    successSoft: Color(0xFFEAF7EF),
    danger: Color(0xFFC8202F),
    dangerSoft: Color(0xFFFDEDEE),
  );
  static const _dark = ChartColors._(
    main: Color(0xFF4F8BE6),
    comparison: Color(0xFF2BA98A),
    ink: BrainyColors.darkInk,
    muted: BrainyColors.darkMuted,
    line: BrainyColors.darkLine,
    surface: BrainyColors.darkElevated,
    success: Color(0xFF5EDC8C),
    successSoft: Color(0xFF233A2C),
    danger: Color(0xFFFF8A8F),
    dangerSoft: Color(0xFF442A2D),
  );

  static ChartColors of(Brightness brightness) => brightness == Brightness.dark ? _dark : _light;
}
