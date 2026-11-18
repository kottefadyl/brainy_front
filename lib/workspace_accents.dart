import 'package:flutter/material.dart';

import 'brand_assets.dart';

/// Colour accents of the workspace shell, same values as the web client
/// (`blue-light-shell.css` in light, `design-accents.css` in dark).
abstract final class BrainyAccents {
  static const lightBlueStops = [
    Color(0xFF0B55DA),
    Color(0xFF084BC4),
    Color(0xFF063A9B),
  ];
  /// Light sidebar: a soft blue-tinted surface (the web's polish.css), no longer solid blue.
  static const sidebarLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF6F8FE), Color(0xFFEFF3FC)],
  );
  static const stripLight = LinearGradient(
    colors: [Color(0xFF7CF0B4), Color(0xFFFFD166), Color(0xFFFF9AA0)],
  );
  static const stripDark = LinearGradient(
    colors: [Color(0xFF2454E6), Color(0xFF3B82F6), Color(0xFF16A34A)],
    stops: [0, .6, 1],
  );

  static const skyFill = Color(0xFFD9E8FF);
  static const skyInk = Color(0xFF084BC4);
  static const mintFill = Color(0xFFC9F5DC);
  static const mintInk = Color(0xFF0B6B3D);
  static const amberFill = Color(0xFFFFECBF);
  static const amberInk = Color(0xFF7A4700);
  static const darkBlueTint = Color(0x245B8CFF);
  static const darkBlueInk = Color(0xFF8CB0FF);
  static const darkGreenTint = Color(0x2134D27B);
  static const darkGreenInk = Color(0xFF5EDC8C);

  static const _lightTiles = [
    (fill: Color(0xFFD9E8FF), ink: Color(0xFF0B55DA)),
    (fill: Color(0xFFC9F5DC), ink: Color(0xFF0B7A45)),
    (fill: Color(0xFFFFDCE3), ink: Color(0xFFC2255C)),
    (fill: Color(0xFFFFECBF), ink: Color(0xFF9A5B00)),
    (fill: Color(0xFFE6DEFF), ink: Color(0xFF6D3FD1)),
    (fill: Color(0xFFC8F3F3), ink: Color(0xFF0B7285)),
  ];
  static const _darkTiles = [
    (fill: darkBlueTint, ink: darkBlueInk),
    (fill: darkGreenTint, ink: darkGreenInk),
    (fill: Color(0x21FF5A5F), ink: Color(0xFFFF8A8F)),
    (fill: Color(0x14FFFFFF), ink: Color(0xFFF3F4F6)),
  ];

  static ({Color fill, Color ink}) tile(int index, bool dark) {
    final tiles = dark ? _darkTiles : _lightTiles;
    return tiles[index % tiles.length];
  }
}

/// The Brainy mark on the navigation surface: it carries its own blue tile, so it reads in both themes.
class ShellLogo extends StatelessWidget {
  const ShellLogo({super.key, required this.dark, this.size = 40});

  final bool dark;
  final double size;

  @override
  Widget build(BuildContext context) => BrainyMark(size: size);
}

/// Short multicolour line under the sidebar tagline.
class BrainyAccentBar extends StatelessWidget {
  const BrainyAccentBar({super.key, required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 3,
    decoration: BoxDecoration(
      gradient: dark ? BrainyAccents.stripDark : BrainyAccents.stripLight,
      borderRadius: BorderRadius.circular(2),
    ),
  );
}
