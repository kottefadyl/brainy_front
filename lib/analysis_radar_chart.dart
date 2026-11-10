// Radar (T23/1), as on the web: one axis per category of a result, the compared period dashed.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chart_math.dart';
import 'chart_scatter_radar.dart';
import 'design_tokens.dart';

class AnalysisRadarChart extends StatefulWidget {
  const AnalysisRadarChart({super.key, required this.rows, this.comparisonRows = const [], this.unit, this.title, required this.french});
  final List<Map<String, dynamic>> rows;
  final List<Map<String, dynamic>> comparisonRows;
  final String? unit;
  final String? title;
  final bool french;

  @override
  State<AnalysisRadarChart> createState() => _AnalysisRadarChartState();
}

class _AnalysisRadarChartState extends State<AnalysisRadarChart> {
  final _focus = FocusNode(debugLabel: 'radar');
  int? _active;
  bool _showComparison = true;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  double _value(Map<String, dynamic> row) => math.max(0, double.tryParse(row['value'] as String? ?? '') ?? 0);

  @override
  Widget build(BuildContext context) {
    final fr = widget.french;
    final colors = ChartColors.of(Theme.of(context).brightness);
    final rows = widget.rows;
    final values = rows.map(_value).toList();
    // The compared period is matched by category key, so a missing category reads as "no data".
    final compared = widget.comparisonRows.isEmpty ? null : [for (final row in rows) widget.comparisonRows.where((item) => item['group'] == row['group']).firstOrNull];
    final comparedValues = compared?.map((row) => row == null ? null : _value(row)).toList();
    final scale = niceScale([...values, ...?comparedValues?.whereType<double>()]);
    String fmt(double value) => formatChartValue(value, widget.unit, fr);
    final current = _active == null ? null : rows[_active!];
    String describe(int index) => '${rows[index]['label']}${fr ? ' : ' : ': '}${fmt(values[index])}';
    void move(int step) => setState(() => _active = ((_active ?? (step > 0 ? -1 : 0)) + step) % rows.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 16, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 22, height: 3, color: colors.main),
            const SizedBox(width: 8),
            Text('${widget.title ?? (fr ? 'Résultat' : 'Result')}${widget.unit == null ? '' : ' · ${widget.unit}'}'),
          ]),
          if (compared != null)
            TextButton.icon(
              key: const Key('radar-comparison-toggle'),
              onPressed: () => setState(() => _showComparison = !_showComparison),
              icon: CustomPaint(size: const Size(22, 3), painter: _DashPainter(colors.comparison)),
              label: Text(fr ? 'Période comparée' : 'Compared period', style: TextStyle(decoration: _showComparison ? null : TextDecoration.lineThrough)),
            ),
        ]),
        const SizedBox(height: 8),
        Focus(
          focusNode: _focus,
          onKeyEvent: (node, event) {
            if (event is KeyUpEvent) return KeyEventResult.ignored;
            final key = event.logicalKey;
            if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.arrowDown) { move(1); return KeyEventResult.handled; }
            if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowUp) { move(-1); return KeyEventResult.handled; }
            if (key == LogicalKeyboardKey.escape) { setState(() => _active = null); return KeyEventResult.handled; }
            return KeyEventResult.ignored;
          },
          child: Semantics(
            label: fr ? 'Graphique radar, ${rows.length} catégories' : 'Radar chart, ${rows.length} categories',
            // Screen readers need the next and previous values whenever one is announced.
            value: current == null ? null : describe(_active!),
            increasedValue: current == null ? null : describe((_active! + 1) % rows.length),
            decreasedValue: current == null ? null : describe((_active! - 1 + rows.length) % rows.length),
            onIncrease: () => move(1),
            onDecrease: () => move(-1),
            child: LayoutBuilder(builder: (context, constraints) {
              final side = math.max(240.0, math.min(constraints.maxWidth, 440.0));
              final geometry = _RadarGeometry(count: rows.length, side: side);
              return Center(
                child: GestureDetector(
                  key: const Key('radar-plot'),
                  onTapDown: (details) {
                    _focus.requestFocus();
                    setState(() => _active = geometry.nearest(details.localPosition, values, scale.high));
                  },
                  child: CustomPaint(
                    size: Size(side, side),
                    painter: _RadarPainter(
                      geometry: geometry,
                      labels: [for (final row in rows) '${row['label']}'],
                      values: values,
                      compared: _showComparison ? comparedValues : null,
                      high: scale.high,
                      active: _active,
                      colors: colors,
                      scaleText: fmt(scale.high),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        if (current != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${current['label']} · ${fmt(values[_active!])}${compared == null ? '' : ' · ${fr ? 'Comparée : ' : 'Compared: '}${comparedValues![_active!] == null ? (fr ? 'aucune donnée' : 'no data') : fmt(comparedValues[_active!]!)}'}',
              key: const Key('radar-selection'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

class _RadarGeometry {
  _RadarGeometry({required this.count, required this.side}) : radius = side / 2 - (side < 340 ? 54 : 74);
  final int count;
  final double side;
  final double radius;
  Offset point(int index, double ratio) { final at = radarPoint(index, count, ratio, side / 2, side / 2, radius); return Offset(at.x, at.y); }

  /// The axis whose value point, or label, is nearest the tap.
  int nearest(Offset position, List<double> values, double high) {
    var best = 0;
    var bestDistance = double.infinity;
    for (var index = 0; index < count; index++) {
      for (final ratio in [high > 0 ? values[index] / high : 0.0, 1.15]) {
        final distance = (point(index, ratio) - position).distance;
        if (distance < bestDistance) { best = index; bestDistance = distance; }
      }
    }
    return best;
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.geometry, required this.labels, required this.values, required this.compared, required this.high, required this.active, required this.colors, required this.scaleText});
  final _RadarGeometry geometry;
  final List<String> labels;
  final List<double> values;
  final List<double?>? compared;
  final double high;
  final int? active;
  final ChartColors colors;
  final String scaleText;

  Path _polygon(List<double> list) {
    final path = Path();
    for (var index = 0; index < list.length; index++) {
      final at = geometry.point(index, high > 0 ? list[index] / high : 0);
      index == 0 ? path.moveTo(at.dx, at.dy) : path.lineTo(at.dx, at.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final grid = Paint()..color = colors.line..style = PaintingStyle.stroke..strokeWidth = 1;
    for (final ring in [0.25, 0.5, 0.75, 1.0]) {
      canvas.drawPath(_polygon(List.filled(values.length, high * ring)), grid);
    }
    for (var index = 0; index < values.length; index++) {
      canvas.drawLine(center, geometry.point(index, 1), grid);
    }
    final scale = TextPainter(text: TextSpan(text: scaleText, style: TextStyle(fontSize: 11.5, color: colors.muted)), textDirection: TextDirection.ltr)..layout();
    scale.paint(canvas, Offset(center.dx + 6, center.dy - geometry.radius + 6));
    final other = compared;
    if (other != null) {
      final dashed = Paint()..color = colors.comparison..style = PaintingStyle.stroke..strokeWidth = 2;
      final points = [for (var index = 0; index < other.length; index++) geometry.point(index, high > 0 ? (other[index] ?? 0) / high : 0)];
      for (var index = 0; index < points.length; index++) {
        final start = points[index], end = points[(index + 1) % points.length];
        final length = (end - start).distance;
        if (length == 0) continue;
        final direction = (end - start) / length;
        for (var travelled = 0.0; travelled < length; travelled += 11) {
          canvas.drawLine(start + direction * travelled, start + direction * math.min(travelled + 6, length), dashed);
        }
      }
    }
    final area = _polygon(values);
    canvas.drawPath(area, Paint()..color = colors.main.withValues(alpha: .18));
    canvas.drawPath(area, Paint()..color = colors.main..style = PaintingStyle.stroke..strokeWidth = 2.2..strokeJoin = StrokeJoin.round);
    final small = size.width < 340;
    for (var index = 0; index < values.length; index++) {
      final selected = index == active;
      final at = geometry.point(index, high > 0 ? values[index] / high : 0);
      canvas.drawCircle(at, selected ? 6.5 : 4, Paint()..color = colors.main);
      if (selected) canvas.drawCircle(at, 6.5, Paint()..color = colors.ink..style = PaintingStyle.stroke..strokeWidth = 2);
      final limit = small ? 12 : 18;
      final text = labels[index].length > limit ? '${labels[index].substring(0, limit - 1)}…' : labels[index];
      final label = TextPainter(text: TextSpan(text: text, style: TextStyle(fontSize: 12.5, color: colors.ink, fontWeight: selected ? FontWeight.w700 : FontWeight.w400)), textDirection: TextDirection.ltr)..layout();
      final anchor = geometry.point(index, 1) + (geometry.point(index, 1) - center) / geometry.radius * 14;
      final dx = (anchor.dx - center.dx).abs() < 6 ? anchor.dx - label.width / 2 : anchor.dx > center.dx ? anchor.dx : anchor.dx - label.width;
      label.paint(canvas, Offset(dx, anchor.dy - label.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => old.values != values || old.compared != compared || old.active != active || old.colors != colors || old.geometry.side != geometry.side;
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = size.height;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, size.height / 2), Offset(math.min(x + 5, size.width), size.height / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) => old.color != color;
}
