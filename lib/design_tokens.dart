import 'package:flutter/material.dart';

/// Shared surfaces, same values as `brainy_web_app/app/design-system.css`.
abstract final class BrainyColors {
  static const lightCanvas = Color(0xFFF6F7F9);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightInk = Color(0xFF0E1116);
  static const lightMuted = Color(0xFF586070);
  static const lightLine = Color(0xFFE4E7EC);
  static const navigationBlue = Color(0xFF084BC4);
  static const lightSidebar = navigationBlue;
  static const lightHero = navigationBlue;
  static const lightAccent = Color(0xFF1F4FD8);
  static const lightAccentSoft = Color(0xFFEEF3FE);
  static const blue = Color(0xFF2454E6);

  static const darkCanvas = Color(0xFF0F1012);
  static const darkSurface = Color(0xFF17181B);
  static const darkElevated = Color(0xFF1E1F23);
  static const darkInk = Color(0xFFF3F4F6);
  static const darkMuted = Color(0xFFA3A8B2);
  static const darkLine = Color(0xFF2A2C31);
  static const darkLineStrong = Color(0xFF3A3C43);
  static const darkControl = Color(0xFF6F7480);
  static const darkSidebar = Color(0xFF0B0C0E);
  static const darkHero = darkSurface;
  static const darkAccent = Color(0xFF8CB0FF);
  static const darkAccentSoft = Color(0xFF1C2A47);
  static const darkOnAccent = Color(0xFF142443);
  static const darkPrimary = Color(0xFF3366EE);

  static const brandRed = Color(0xFFF1919D);
  static const lightControl = Color(0xFF8A92A1);
}

/// Navigation surfaces: deep blue in the light theme, charcoal in the dark one.
abstract final class BrainyNavigationColors {
  static Color ink(bool dark) =>
      dark ? BrainyColors.darkInk : const Color(0xFFFFFFFF);
  static Color muted(bool dark) =>
      dark ? BrainyColors.darkMuted : const Color(0xFFDCE6FF);
  static Color field(bool dark) =>
      dark ? BrainyColors.darkSurface : const Color(0x1FFFFFFF);
  static Color selected(bool dark) =>
      dark ? const Color(0x245B8CFF) : const Color(0xFFFFFFFF);
  static Color border(bool dark) =>
      dark ? BrainyColors.darkLineStrong : const Color(0x6BFFFFFF);
  static Color hover(bool dark) =>
      dark ? const Color(0xFF18191C) : const Color(0x24FFFFFF);
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
    required this.series,
  });

  final Color main, comparison, ink, muted, line, surface;

  /// Up to four series of a cross-tabulation, as `--chart-1` to `--chart-4` on the web.
  final List<Color> series;
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
    series: [Color(0xFF2463CE), Color(0xFF0F8F72), Color(0xFFB9730A), Color(0xFFC2385A)],
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
    series: [Color(0xFF7FB0FF), Color(0xFF5FD1B2), Color(0xFFF2B968), Color(0xFFF28FA6)],
  );

  static ChartColors of(Brightness brightness) => brightness == Brightness.dark ? _dark : _light;
}
