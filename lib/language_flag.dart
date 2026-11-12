// Flags of the two interface languages: the United Kingdom for English, France for French.
import 'package:flutter/material.dart';

class LanguageFlag extends StatelessWidget {
  const LanguageFlag(this.code, {super.key, this.width = 22});
  final String code;
  final double width;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: CustomPaint(size: Size(width, width * 2 / 3), painter: code == 'fr' ? _FrenchFlag() : _BritishFlag()),
      );
}

class _FrenchFlag extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final third = size.width / 3;
    canvas.drawRect(Rect.fromLTWH(0, 0, third, size.height), Paint()..color = const Color(0xFF002654));
    canvas.drawRect(Rect.fromLTWH(third, 0, third, size.height), Paint()..color = Colors.white);
    canvas.drawRect(Rect.fromLTWH(third * 2, 0, third + .5, size.height), Paint()..color = const Color(0xFFCE1126));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BritishFlag extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 60;
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF012169));
    void diagonals(Color color, double width) {
      final paint = Paint()..color = color..strokeWidth = width * unit;
      canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
      canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
    }
    void cross(Color color, double width) {
      final paint = Paint()..color = color..strokeWidth = width * unit;
      canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), paint);
      canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
    }
    diagonals(Colors.white, 8);
    diagonals(const Color(0xFFC8102E), 3);
    cross(Colors.white, 12);
    cross(const Color(0xFFC8102E), 7);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
