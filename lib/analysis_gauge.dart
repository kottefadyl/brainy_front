import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'chart_math.dart';
import 'design_tokens.dart';

/// Parses a target typed with a comma or a point; null unless it is a positive number.
double? parseGaugeTarget(String text) {
  final value = double.tryParse(text.trim().replaceAll(RegExp(r'\s'), '').replaceAll(',', '.'));
  return value != null && value.isFinite && value > 0 ? value : null;
}

/// Progress toward a target: a ratio from 0 to 1 and the share as a whole percentage.
({double ratio, int percent}) gaugeProgress(double value, double target) {
  final share = target > 0 ? value / target : 0.0;
  return (ratio: share.clamp(0.0, 1.0), percent: (math.max(0, share) * 100).round());
}

/// A key figure against a target typed by the person (T23/1 gauge). The
/// target is not stored. Same behaviour as `analysis-gauge.tsx` on the web.
class KeyFigureGauge extends StatefulWidget {
  const KeyFigureGauge({super.key, required this.value, required this.french, this.unit});
  final double value;
  final String? unit;
  final bool french;

  @override
  State<KeyFigureGauge> createState() => _KeyFigureGaugeState();
}

class _KeyFigureGaugeState extends State<KeyFigureGauge> {
  final _target = TextEditingController();

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final french = widget.french;
    final theme = Theme.of(context);
    final colors = ChartColors.of(theme.brightness);
    final target = parseGaugeTarget(_target.text);
    final progress = target == null ? null : gaugeProgress(widget.value, target);
    final reached = progress != null && progress.percent >= 100;
    final description = progress == null || target == null
        ? ''
        : french
        ? '${progress.percent} % de l’objectif : ${formatChartValue(widget.value, widget.unit, true)} sur ${formatChartValue(target, widget.unit, true)}'
        : '${progress.percent}% of the target: ${formatChartValue(widget.value, widget.unit, false)} of ${formatChartValue(target, widget.unit, false)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: TextField(
            key: const ValueKey('gauge-target'),
            controller: _target,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: french ? 'Objectif (facultatif)' : 'Target (optional)',
              hintText: french ? 'ex. 1 000' : 'e.g. 1,000',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        if (_target.text.trim().isNotEmpty && target == null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(french ? 'Entrez un nombre supérieur à zéro.' : 'Enter a number above zero.', style: TextStyle(color: colors.muted, fontSize: 13)),
          ),
        if (progress != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Semantics(
              label: description,
              child: ExcludeSemantics(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: 150,
                      height: 84,
                      child: CustomPaint(
                        key: const ValueKey('gauge-arc'),
                        painter: _GaugePainter(progress.ratio, reached ? colors.series[1] : colors.series[0], colors.line),
                        child: Align(
                          alignment: const Alignment(0, 0.45),
                          child: Text('${progress.percent} %', style: TextStyle(color: colors.ink, fontSize: 22, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(reached ? (french ? 'Objectif atteint' : 'Target reached') : (french ? 'En cours' : 'In progress'),
                              style: TextStyle(color: colors.ink, fontSize: 16, fontWeight: FontWeight.w700)),
                          Text(description, style: TextStyle(color: colors.muted, fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter(this.ratio, this.color, this.track);
  final double ratio;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final radius = math.min(size.width / 2, size.height) - stroke;
    final center = Offset(size.width / 2, size.height - stroke / 2 - 4);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi, math.pi, false, paint..color = track);
    if (ratio > 0) canvas.drawArc(rect, math.pi, math.pi * ratio, false, paint..color = color);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.ratio != ratio || old.color != color || old.track != track;
}
