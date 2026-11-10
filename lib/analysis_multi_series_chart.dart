import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'analysis_chart.dart' show ChartView;
import 'chart_math.dart';
import 'design_tokens.dart';

enum _Marker { circle, square, triangle, diamond }

// Colour, dash and marker together: no series depends on colour alone.
const _dashes = <List<double>?>[null, [8, 4], [2, 4], [10, 4, 2, 4]];
const _markers = _Marker.values;

/// Up to four series from a period × category cross-tabulation (T23/2).
/// Same meaning as `analysis-multi-series-chart.tsx` on the web.
class AnalysisMultiSeriesChart extends StatefulWidget {
  const AnalysisMultiSeriesChart({
    super.key,
    required this.multi,
    required this.french,
    required this.view,
    required this.onViewChange,
    required this.height,
    this.unit,
  });

  final MultiSeries multi;
  final String? unit;
  final bool french;
  final ChartView view;
  final ValueChanged<ChartView> onViewChange;
  final double height;

  @override
  State<AnalysisMultiSeriesChart> createState() => _AnalysisMultiSeriesChartState();
}

class _AnalysisMultiSeriesChartState extends State<AnalysisMultiSeriesChart> {
  final _active = ValueNotifier<int?>(null);
  final _focus = FocusNode(debugLabel: 'multi-series chart');
  final _hidden = <String>{};
  bool _showFocus = false;
  int _rove = 0;

  @override
  void didUpdateWidget(covariant AnalysisMultiSeriesChart old) {
    super.didUpdateWidget(old);
    if (!identical(old.multi, widget.multi)) {
      _hidden.clear();
      _active.value = null;
      _rove = 0;
    }
  }

  @override
  void dispose() {
    _active.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<int> get _visible => [
    for (var index = 0; index < widget.multi.series.length; index++)
      if (!_hidden.contains(widget.multi.series[index].key)) index,
  ];

  /// Long period runs are thinned on the visible total, so that peaks of every series survive.
  List<int> _kept(List<int> visible) {
    final periods = widget.multi.periods;
    if (periods.length <= maxChartPoints) return [for (var index = 0; index < periods.length; index++) index];
    final sums = [
      for (var index = 0; index < periods.length; index++)
        visible.fold<double>(0, (sum, series) => sum + (widget.multi.series[series].points[index]?.value.abs() ?? 0)),
    ];
    return lttbIndices(sums, maxChartPoints);
  }

  void _select(int order) {
    _rove = order;
    _active.value = order;
  }

  KeyEventResult _onKey(int count, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final current = _active.value ?? _rove;
    int? next;
    if (key == LogicalKeyboardKey.arrowRight) next = math.min(count - 1, current + 1);
    if (key == LogicalKeyboardKey.arrowLeft) next = math.max(0, current - 1);
    if (key == LogicalKeyboardKey.home) next = 0;
    if (key == LogicalKeyboardKey.end) next = count - 1;
    if (next != null) {
      _select(next);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape && _active.value != null) {
      _active.value = null;
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _toggle(String key) => setState(() {
    if (_hidden.contains(key)) {
      _hidden.remove(key);
    } else if (widget.multi.series.length - _hidden.length > 1) {
      _hidden.add(key);
    }
    _active.value = null;
  });

  String _valueText(ChartPoint? point) =>
      point == null ? (widget.french ? 'aucune donnée' : 'no data') : formatChartValue(point.value, widget.unit, widget.french);

  String _describe(int period, List<int> visible) => [
    fullChartLabel(widget.multi.periods[period], widget.french),
    for (final series in visible)
      '${widget.multi.series[series].label} : ${_valueText(widget.multi.series[series].points[period])}',
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final french = widget.french;
    final theme = Theme.of(context);
    final colors = ChartColors.of(theme.brightness);
    final visible = _visible;
    final kept = _kept(visible);
    final characterScale = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3).scale(1);
    final multi = widget.multi;
    final note = TextStyle(color: colors.muted, fontSize: 13);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [_legend(colors), _viewSwitch(theme)],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, constraints) => _plot(
              context,
              _Geometry(
                size: Size(constraints.maxWidth, widget.height),
                multi: multi,
                visible: visible,
                kept: kept,
                line: widget.view == ChartView.line,
                french: french,
                characterScale: characterScale,
              ),
              colors,
            ),
          ),
        ),
        if (multi.hiddenSeries > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              french
                  ? '${multi.series.length} catégories sur ${multi.series.length + multi.hiddenSeries} tracées : celles dont le total est le plus grand. La liste ci-dessous contient tout.'
                  : '${multi.series.length} of ${multi.series.length + multi.hiddenSeries} categories drawn: those with the largest totals. The list below contains every value.',
              style: note,
            ),
          ),
        if (multi.skippedRows > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              multi.skippedRows == 1
                  ? (french ? '1 valeur sans date n’est pas tracée ; elle reste dans la liste.' : '1 value without a date is not drawn; it stays in the list.')
                  : (french
                        ? '${multi.skippedRows} valeurs sans date ne sont pas tracées ; elles restent dans la liste.'
                        : '${multi.skippedRows} values without a date are not drawn; they stay in the list.'),
              style: note,
            ),
          ),
        if (multi.periods.length > maxChartPoints)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              french
                  ? 'Graphique simplifié : ${kept.length} périodes affichées sur ${multi.periods.length}.'
                  : 'Simplified chart: ${kept.length} of ${multi.periods.length} periods shown.',
              style: note,
            ),
          ),
      ],
    );
  }

  Widget _legend(ChartColors colors) {
    final french = widget.french;
    return Semantics(
      container: true,
      label: french ? 'Séries affichées' : 'Shown series',
      child: Wrap(
        children: [
          for (var index = 0; index < widget.multi.series.length; index++)
            Builder(
              builder: (context) {
                final series = widget.multi.series[index];
                final hidden = _hidden.contains(series.key);
                return Semantics(
                  button: true,
                  toggled: !hidden,
                  child: Tooltip(
                    message: hidden ? (french ? 'Afficher cette série' : 'Show this series') : (french ? 'Masquer cette série' : 'Hide this series'),
                    child: InkWell(
                      key: ValueKey('multi-series-legend-$index'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _toggle(series.key),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _SeriesKey(index: index, color: colors.series[index], surface: colors.surface),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  series.label,
                                  style: TextStyle(
                                    color: hidden ? colors.muted : colors.ink,
                                    fontSize: 13,
                                    decoration: hidden ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _viewSwitch(ThemeData theme) {
    final french = widget.french;
    Widget button(ChartView view, String label, IconData icon) => IconButton(
      tooltip: label,
      isSelected: widget.view == view,
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      color: widget.view == view ? theme.colorScheme.primary : null,
      onPressed: () => widget.onViewChange(view),
      icon: Icon(icon, size: 20),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(ChartView.line, french ? 'Courbes' : 'Lines', Icons.show_chart_rounded),
        button(ChartView.bar, french ? 'Barres' : 'Bars', Icons.bar_chart_rounded),
      ],
    );
  }

  Widget _plot(BuildContext context, _Geometry geometry, ChartColors colors) {
    final french = widget.french;
    final count = geometry.kept.length;
    void pick(Offset position) => _select(geometry.indexAt(position.dx));
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TapRegion(
      onTapOutside: (_) => _active.value = null,
      child: ValueListenableBuilder<int?>(
        valueListenable: _active,
        builder: (context, active, plot) {
          final current = math.min(count - 1, active ?? _rove);
          final next = math.min(count - 1, current + 1);
          final previous = math.max(0, current - 1);
          return Semantics(
            container: true,
            label: '${french ? 'Graphique' : 'Chart'}: ${geometry.visible.length} ${french ? 'séries' : 'series'}, ${widget.multi.periods.length} ${french ? 'périodes' : 'periods'}',
            value: _describe(geometry.kept[current], geometry.visible),
            increasedValue: _describe(geometry.kept[next], geometry.visible),
            decreasedValue: _describe(geometry.kept[previous], geometry.visible),
            onIncrease: () => _select(next),
            onDecrease: () => _select(previous),
            child: plot,
          );
        },
        child: Focus(
          focusNode: _focus,
          onKeyEvent: (_, event) => _onKey(count, event),
          onFocusChange: (focused) {
            setState(() => _showFocus = focused && FocusManager.instance.highlightMode == FocusHighlightMode.traditional);
            if (!focused) _active.value = null;
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.precise,
            onHover: (event) {
              if (event.kind == PointerDeviceKind.mouse) pick(event.localPosition);
            },
            onExit: (event) {
              if (event.kind == PointerDeviceKind.mouse) _active.value = null;
            },
            // A horizontal drag selects periods; a vertical one still scrolls the page.
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                _focus.requestFocus();
                pick(details.localPosition);
              },
              onHorizontalDragStart: (details) => pick(details.localPosition),
              onHorizontalDragUpdate: (details) => pick(details.localPosition),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        key: const ValueKey('multi-series-chart-series'),
                        painter: _SeriesPainter(geometry, colors),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(painter: _SelectionPainter(geometry, colors, _active)),
                    ),
                  ),
                  if (_showFocus)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                          ),
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ValueListenableBuilder<int?>(
                        valueListenable: _active,
                        builder: (context, active, _) {
                          if (active == null || active >= count) return const SizedBox.shrink();
                          return TweenAnimationBuilder<Offset>(
                            tween: Tween<Offset>(end: geometry.anchorFor(active)),
                            duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 90),
                            curve: Curves.easeOutCubic,
                            builder: (context, anchor, child) => CustomSingleChildLayout(delegate: _TooltipLayout(anchor), child: child),
                            child: _Tooltip(
                              period: geometry.kept[active],
                              multi: widget.multi,
                              visible: geometry.visible,
                              colors: colors,
                              french: french,
                              valueText: _valueText,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Geometry {
  _Geometry({
    required this.size,
    required this.multi,
    required this.visible,
    required this.kept,
    required this.line,
    required this.french,
    required this.characterScale,
  }) : scale = niceScale([
         for (final series in visible)
           for (final point in multi.series[series].points)
             if (point != null) point.value,
       ]) {
    final longest = scale.ticks.fold<int>(0, (size, tick) => math.max(size, compactChartNumber(tick, french).length));
    left = math.min(72, math.max(36, longest * 8 * characterScale + 12));
    plotWidth = math.max(40, size.width - left - right);
    band = plotWidth / kept.length;
    positions = [
      for (var order = 0; order < kept.length; order++)
        line ? left + order * plotWidth / math.max(1, kept.length - 1) : left + band * (order + 0.5),
    ];
    ticks = chooseAxisTicks([for (final index in kept) multi.periods[index]], positions, french, characterWidth: 7 * characterScale);
    axis = size.height - 34;
    barWidth = math.max(1, math.min(18, (band - math.min(6, band * 0.3) - (visible.length - 1) * 2) / math.max(1, visible.length)));
  }

  static const top = 14.0;
  static const right = 14.0;

  final Size size;
  final MultiSeries multi;
  final List<int> visible;
  final List<int> kept;
  final bool line;
  final bool french;
  final double characterScale;
  final ChartScale scale;
  late final double left;
  late final double plotWidth;
  late final double band;
  late final double axis;
  late final double barWidth;
  late final List<double> positions;
  late final List<AxisTick> ticks;

  double y(double value) => axis - (value - scale.low) / (scale.high - scale.low) * (axis - top);
  double get baseline => y(0);
  bool get showMarkers => band >= 14;

  int indexAt(double dx) {
    var best = 0;
    for (var order = 1; order < positions.length; order++) {
      if ((positions[order] - dx).abs() < (positions[best] - dx).abs()) best = order;
    }
    return best;
  }

  Offset anchorFor(int order) {
    final values = [
      for (final series in visible)
        if (multi.series[series].points[kept[order]] != null) multi.series[series].points[kept[order]]!.value,
    ];
    return Offset(positions[order], y(values.isEmpty ? scale.low : values.reduce(math.max)));
  }

  List<List<Offset>> runs(int series) {
    final result = <List<Offset>>[[]];
    for (var order = 0; order < kept.length; order++) {
      final point = multi.series[series].points[kept[order]];
      if (point != null) {
        result.last.add(Offset(positions[order], y(point.value)));
      } else if (result.last.isNotEmpty) {
        result.add([]);
      }
    }
    return result.where((run) => run.isNotEmpty).toList();
  }
}

Path _markerPath(_Marker marker, Offset at, double r) {
  final x = at.dx, y = at.dy;
  return switch (marker) {
    _Marker.square => Path()..addRect(Rect.fromCenter(center: at, width: 2 * r, height: 2 * r)),
    _Marker.triangle => Path()
      ..moveTo(x, y - r * 1.2)
      ..lineTo(x + r * 1.1, y + r * 0.9)
      ..lineTo(x - r * 1.1, y + r * 0.9)
      ..close(),
    _Marker.diamond => Path()
      ..moveTo(x, y - r * 1.25)
      ..lineTo(x + r * 1.25, y)
      ..lineTo(x, y + r * 1.25)
      ..lineTo(x - r * 1.25, y)
      ..close(),
    _Marker.circle => Path()..addOval(Rect.fromCircle(center: at, radius: r)),
  };
}

Path _patterned(Path source, List<double>? pattern) {
  if (pattern == null) return source;
  final result = Path();
  for (final metric in source.computeMetrics()) {
    var distance = 0.0;
    var step = 0;
    while (distance < metric.length) {
      final length = pattern[step % pattern.length];
      if (step.isEven) result.addPath(metric.extractPath(distance, math.min(metric.length, distance + length)), Offset.zero);
      distance += length;
      step += 1;
    }
  }
  return result;
}

Path _polyline(List<Offset> run) {
  final path = Path()..moveTo(run.first.dx, run.first.dy);
  for (final point in run.skip(1)) {
    path.lineTo(point.dx, point.dy);
  }
  return path;
}

void _drawMarker(Canvas canvas, int series, Offset at, double r, Color color, Color surface) {
  final path = _markerPath(_markers[series], at, r);
  canvas.drawPath(path, Paint()..color = color);
  canvas.drawPath(
    path,
    Paint()
      ..color = surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );
}

class _SeriesKey extends StatelessWidget {
  const _SeriesKey({required this.index, required this.color, required this.surface});

  final int index;
  final Color color;
  final Color surface;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 22,
    height: 10,
    child: CustomPaint(painter: _SeriesKeyPainter(index, color, surface)),
  );
}

class _SeriesKeyPainter extends CustomPainter {
  const _SeriesKeyPainter(this.index, this.color, this.surface);

  final int index;
  final Color color;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    canvas.drawPath(
      _patterned(Path()
        ..moveTo(1, y)
        ..lineTo(size.width - 1, y), _dashes[index]),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawPath(_markerPath(_markers[index], Offset(size.width / 2, y), 3), Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SeriesKeyPainter old) => old.index != index || old.color != color;
}

class _SeriesPainter extends CustomPainter {
  const _SeriesPainter(this.geometry, this.colors);

  final _Geometry geometry;
  final ChartColors colors;

  void _text(Canvas canvas, String text, Offset at, {TextAlign align = TextAlign.left}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: colors.muted, fontSize: 13 * geometry.characterScale)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = align == TextAlign.right
        ? at.dx - painter.width
        : align == TextAlign.center
        ? at.dx - painter.width / 2
        : at.dx;
    painter.paint(canvas, Offset(dx, at.dy - painter.height / 2));
    painter.dispose();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final g = geometry;
    final grid = Paint()
      ..color = colors.line
      ..strokeWidth = 1;
    for (final tick in g.scale.ticks) {
      canvas.drawLine(Offset(g.left, g.y(tick)), Offset(size.width - _Geometry.right, g.y(tick)), grid);
      _text(canvas, compactChartNumber(tick, g.french), Offset(g.left - 6, g.y(tick)), align: TextAlign.right);
    }
    if (g.line) {
      for (final series in g.visible) {
        final color = colors.series[series];
        final stroke = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        final runs = g.runs(series);
        for (final run in runs) {
          canvas.drawPath(_patterned(_polyline(run), _dashes[series]), stroke);
          // A lone point between gaps would be invisible without its marker.
          if (g.showMarkers || run.length == 1) {
            for (final point in run) {
              _drawMarker(canvas, series, point, 3.5, color, colors.surface);
            }
          }
        }
      }
    } else {
      const corner = Radius.circular(3);
      for (var order = 0; order < g.kept.length; order++) {
        var cursor = g.positions[order] - (g.barWidth * g.visible.length + (g.visible.length - 1) * 2) / 2;
        for (final series in g.visible) {
          final point = g.multi.series[series].points[g.kept[order]];
          if (point != null && point.value != 0) {
            final y = g.y(point.value);
            final rect = Rect.fromLTRB(cursor, math.min(y, g.baseline), cursor + g.barWidth, math.max(y, g.baseline));
            canvas.drawRRect(
              point.value > 0
                  ? RRect.fromRectAndCorners(rect, topLeft: corner, topRight: corner)
                  : RRect.fromRectAndCorners(rect, bottomLeft: corner, bottomRight: corner),
              Paint()..color = colors.series[series],
            );
          }
          cursor += g.barWidth + 2;
        }
      }
    }
    canvas.drawLine(
      Offset(g.left, g.baseline),
      Offset(size.width - _Geometry.right, g.baseline),
      Paint()
        ..color = colors.muted
        ..strokeWidth = 1,
    );
    for (final tick in g.ticks) {
      final x = g.positions[tick.index];
      final half = tick.label.length * 3.5 * g.characterScale;
      final align = x - half < 0
          ? TextAlign.left
          : x + half > size.width
          ? TextAlign.right
          : TextAlign.center;
      _text(canvas, tick.label, Offset(x, size.height - 12), align: align);
    }
  }

  @override
  bool shouldRepaint(covariant _SeriesPainter old) =>
      old.geometry.size != geometry.size ||
      !identical(old.geometry.multi, geometry.multi) ||
      !listEquals(old.geometry.visible, geometry.visible) ||
      !listEquals(old.geometry.kept, geometry.kept) ||
      old.geometry.line != geometry.line ||
      old.geometry.french != geometry.french ||
      old.colors != colors;
}

class _SelectionPainter extends CustomPainter {
  _SelectionPainter(this.geometry, this.colors, this.active) : super(repaint: active);

  final _Geometry geometry;
  final ChartColors colors;
  final ValueListenable<int?> active;

  @override
  void paint(Canvas canvas, Size size) {
    final order = active.value;
    final g = geometry;
    if (order == null || order >= g.kept.length) return;
    final x = g.positions[order];
    if (!g.line) {
      canvas.drawRect(
        Rect.fromLTRB(x - g.band / 2, _Geometry.top, x + g.band / 2, g.axis),
        Paint()..color = colors.muted.withValues(alpha: 0.14),
      );
      return;
    }
    canvas.drawLine(
      Offset(x, _Geometry.top),
      Offset(x, g.axis),
      Paint()
        ..color = colors.muted
        ..strokeWidth = 1,
    );
    for (final series in g.visible) {
      final point = g.multi.series[series].points[g.kept[order]];
      if (point != null) _drawMarker(canvas, series, Offset(x, g.y(point.value)), 5.5, colors.series[series], colors.surface);
    }
  }

  @override
  bool shouldRepaint(covariant _SelectionPainter old) => !identical(old.geometry, geometry) || old.colors != colors;
}

class _TooltipLayout extends SingleChildLayoutDelegate {
  const _TooltipLayout(this.anchor);

  final Offset anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => BoxConstraints(maxWidth: math.min(250.0, constraints.maxWidth));

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final left = (anchor.dx - childSize.width / 2).clamp(0.0, math.max(0.0, size.width - childSize.width)).toDouble();
    final above = anchor.dy - childSize.height - 12;
    return Offset(left, above >= 0 ? above : anchor.dy + 14);
  }

  @override
  bool shouldRelayout(covariant _TooltipLayout old) => old.anchor != anchor;
}

class _Tooltip extends StatelessWidget {
  const _Tooltip({
    required this.period,
    required this.multi,
    required this.visible,
    required this.colors,
    required this.french,
    required this.valueText,
  });

  final int period;
  final MultiSeries multi;
  final List<int> visible;
  final ChartColors colors;
  final bool french;
  final String Function(ChartPoint?) valueText;

  @override
  Widget build(BuildContext context) {
    final meta = TextStyle(color: colors.muted, fontSize: 13);
    return Material(
      key: const ValueKey('multi-series-chart-tooltip'),
      color: colors.surface,
      elevation: 6,
      shadowColor: Colors.black38,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: colors.line)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fullChartLabel(multi.periods[period], french), style: meta),
            for (final series in visible) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _SeriesKey(index: series, color: colors.series[series], surface: colors.surface),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(multi.series[series].label, style: TextStyle(color: colors.ink, fontSize: 13)),
                        if (multi.series[series].points[period] case final point?) Text(entryCount(point.count, french), style: meta),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    valueText(multi.series[series].points[period]),
                    style: TextStyle(color: colors.ink, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
