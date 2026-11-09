import 'package:flutter/material.dart';

/// Brainy mark: half brain joined to half circuit, drawn like the web's
/// `BrainyLogo.tsx` so that it sits on any surface.
class BrainyLogo extends StatelessWidget {
  const BrainyLogo({
    super.key,
    required this.ink,
    required this.chip,
    required this.chipLine,
    required this.node,
    this.size = 40,
  });

  final Color ink, chip, chipLine, node;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Brainy',
    image: true,
    child: CustomPaint(
      size: Size.square(size),
      painter: _LogoPainter(ink, chip, chipLine, node),
    ),
  );
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter(this.ink, this.chip, this.chipLine, this.node);

  final Color ink, chip, chipLine, node;

  static Path _brain() => Path()
    ..moveTo(31, 7.5)
    ..cubicTo(26, 5.6, 20, 6.6, 16.8, 10.8)
    ..cubicTo(11.8, 10.8, 7.6, 14.8, 8.2, 20)
    ..cubicTo(4.8, 22.8, 4.2, 28, 6.4, 31.2)
    ..cubicTo(4.2, 35, 5, 40.4, 8.8, 43)
    ..cubicTo(8.8, 47.6, 12.4, 51.6, 17, 51.6)
    ..cubicTo(19.6, 55.8, 25.2, 57.8, 31, 56.2)
    ..close();

  static Path _gyrus(double x, double y, List<double> c) => Path()
    ..moveTo(x, y)
    ..relativeCubicTo(c[0], c[1], c[2], c[3], c[4], c[5]);

  static final _gyri = [
    _gyrus(25, 12.5, [-3.2, 1, -4.6, 3.8, -3.6, 6.6]),
    _gyrus(12.5, 19.5, [3.2, -.3, 5.6, 1.8, 5.8, 5]),
    _gyrus(27, 24, [-3.4, 0, -5.6, 2.2, -5.6, 5.4]),
    _gyrus(9.5, 32.5, [3.2, -1.2, 6.4, -.2, 7.8, 2.4]),
    _gyrus(26.5, 36, [-2.6, 1.2, -3.6, 4, -2.6, 6.6]),
    _gyrus(14.5, 45, [2.2, -2.2, 5.6, -2.4, 7.8, -.2]),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64);
    const bounds = Rect.fromLTWH(0, 0, 64, 64);

    canvas.saveLayer(bounds, Paint());
    canvas.drawPath(_brain(), Paint()..color = ink);
    final cut = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (final gyrus in _gyri) {
      canvas.drawPath(gyrus, cut);
    }
    canvas.restore();

    canvas.drawRRect(
      RRect.fromLTRBR(33, 19, 42.5, 45, const Radius.circular(2.2)),
      Paint()..color = chip,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(35.6, 22.5, 39.9, 41.5, const Radius.circular(1)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = chipLine.withValues(alpha: .55),
    );

    final trace = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = ink;
    for (final points in const [
      [Offset(37.7, 19), Offset(37.7, 12.8)],
      [Offset(42.5, 24), Offset(46.5, 24), Offset(51.4, 19.1)],
      [Offset(42.5, 32), Offset(50, 32)],
      [Offset(42.5, 40), Offset(46.5, 40), Offset(51.4, 44.9)],
      [Offset(37.7, 45), Offset(37.7, 51.2)],
    ]) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, trace);
    }

    final red = Paint()..color = node;
    final blue = Paint()..color = chip;
    canvas.drawCircle(const Offset(37.7, 10.4), 2.6, red);
    canvas.drawCircle(const Offset(53.6, 16.9), 3.3, blue);
    canvas.drawCircle(const Offset(52.8, 32), 2.6, red);
    canvas.drawCircle(const Offset(53.6, 47.1), 3.3, blue);
    canvas.drawCircle(const Offset(37.7, 53.6), 2.6, red);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.ink != ink ||
      old.chip != chip ||
      old.chipLine != chipLine ||
      old.node != node;
}
