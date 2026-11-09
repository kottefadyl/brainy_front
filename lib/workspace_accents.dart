import 'package:flutter/material.dart';

import 'brainy_logo.dart';

/// Colour accents of the workspace shell, same values as the web client
/// (`blue-light-shell.css` in light, `design-accents.css` in dark).
abstract final class BrainyAccents {
  static const lightBlueStops = [
    Color(0xFF0B55DA),
    Color(0xFF084BC4),
    Color(0xFF063A9B),
  ];
  static const sidebarLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: lightBlueStops,
    stops: [0, .52, 1],
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

/// The Brainy mark in the colours of the navigation surface.
class ShellLogo extends StatelessWidget {
  const ShellLogo({super.key, required this.dark, this.size = 40});

  final bool dark;
  final double size;

  @override
  Widget build(BuildContext context) => BrainyLogo(
    size: size,
    ink: dark ? const Color(0xFFF3F4F6) : Colors.white,
    chip: dark ? const Color(0xFF4C7DF5) : const Color(0xFFA9C2FF),
    chipLine: dark ? Colors.white : const Color(0xFF084BC4),
    node: dark ? const Color(0xFFFF5A5F) : const Color(0xFFFF9AA0),
  );
}

/// The collection icon: a folder carrying a heart, drawn like the web's.
class FolderHeartIcon extends StatelessWidget {
  const FolderHeartIcon({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _FolderHeartPainter(color),
  );
}

class _FolderHeartPainter extends CustomPainter {
  const _FolderHeartPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    const r = Radius.circular(2);
    canvas.drawPath(
      Path()
        ..moveTo(11, 20)
        ..lineTo(4, 20)
        ..arcToPoint(const Offset(2, 18), radius: r)
        ..lineTo(2, 5)
        ..arcToPoint(const Offset(4, 3), radius: r)
        ..lineTo(7.9, 3)
        ..arcToPoint(const Offset(9.59, 3.9), radius: r)
        ..lineTo(10.4, 5.1)
        ..arcToPoint(const Offset(12.07, 6), radius: r, clockwise: false)
        ..lineTo(20, 6)
        ..arcToPoint(const Offset(22, 8), radius: r)
        ..lineTo(22, 9.5),
      stroke,
    );
    const heart = Radius.circular(2.43);
    canvas.drawPath(
      Path()
        ..moveTo(13.9, 17.45)
        ..relativeCubicTo(-1.2, -1.2, -1.14, -2.8, -.2, -3.73)
        ..relativeArcToPoint(const Offset(3.44, 0), radius: heart)
        ..relativeLineTo(.36, .34)
        ..relativeLineTo(.34, -.34)
        ..relativeArcToPoint(const Offset(3.45, -.01), radius: heart)
        ..relativeCubicTo(.95, .95, 1, 2.53, -.2, 3.74)
        ..lineTo(17.5, 21)
        ..close(),
      stroke,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FolderHeartPainter old) => old.color != color;
}

/// Coloured icon tile of a collection, rotated by its position in the list.
class CollectionColorTile extends StatelessWidget {
  const CollectionColorTile({
    super.key,
    required this.index,
    required this.dark,
  });

  final int index;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final tile = BrainyAccents.tile(index, dark);
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tile.fill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: FolderHeartIcon(size: 18, color: tile.ink),
    );
  }
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

/// Faint circuit decoration of the collection header.
class CircuitPattern extends StatelessWidget {
  const CircuitPattern({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _CircuitPainter(color));
}

class _CircuitPainter extends CustomPainter {
  const _CircuitPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 260);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final points in const [
      [Offset(20, 40), Offset(80, 40), Offset(100, 60), Offset(170, 60)],
      [
        Offset(60, 100),
        Offset(110, 100),
        Offset(130, 80),
        Offset(190, 80),
        Offset(210, 100),
        Offset(230, 100),
      ],
      [Offset(40, 150), Offset(130, 150), Offset(150, 130), Offset(190, 130)],
    ]) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
    for (final (center, radius) in const [
      (Offset(170, 60), 4.0),
      (Offset(240, 100), 4.0),
      (Offset(190, 130), 4.0),
      (Offset(20, 40), 3.0),
      (Offset(40, 150), 3.0),
    ]) {
      canvas.drawCircle(center, radius, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CircuitPainter old) => old.color != color;
}
