import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chart_math.dart';
import 'design_tokens.dart';

enum ChartView { line, bar }

enum _Series { main, comparison }

/// Interactive result chart. The series are painted once on their own layer;
/// moving the selection only repaints the small layer above them.
class AnalysisChart extends StatefulWidget {
  const AnalysisChart({
    super.key,
    required this.rows,
    required this.french,
    required this.view,
    required this.views,
    required this.onViewChange,
    required this.height,
    this.comparisonRows = const [],
    this.unit,
  });

  final List<Map<String, dynamic>> rows;
  final List<Map<String, dynamic>> comparisonRows;
  final String? unit;
  final bool french;
  final ChartView view;
  final List<ChartView> views;
  final ValueChanged<ChartView> onViewChange;
  final double height;

  @override
  State<AnalysisChart> createState() => _AnalysisChartState();
}

class _AnalysisChartState extends State<AnalysisChart> {
  final _active = ValueNotifier<int?>(null);
  final _focus = FocusNode(debugLabel: 'analysis chart');
  late List<ChartSlot> _allSlots;
  late List<ChartSlot> _slots;
  _Series? _isolated;
  bool _showFocus = false;
  int _rove = 0;

  bool get _compared => widget.comparisonRows.isNotEmpty;
  bool get _showMain => _isolated != _Series.comparison;
  bool get _showComparison => _compared && _isolated != _Series.main;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(covariant AnalysisChart old) {
    super.didUpdateWidget(old);
    if (!identical(old.rows, widget.rows) ||
        !identical(old.comparisonRows, widget.comparisonRows)) {
      _prepare();
      _active.value = null;
      _rove = 0;
    }
  }

  void _prepare() {
    _allSlots = alignSeries(
      widget.rows.map(ChartPoint.fromRow).toList(),
      widget.comparisonRows.map(ChartPoint.fromRow).toList(),
    );
    _slots = sampleSlots(_allSlots);
  }

  @override
  void dispose() {
    _active.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _select(int index) {
    _rove = index;
    _active.value = index;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final last = _slots.length - 1;
    final current = _active.value ?? _rove;
    int? next;
    if (key == LogicalKeyboardKey.arrowRight) next = math.min(last, current + 1);
    if (key == LogicalKeyboardKey.arrowLeft) next = math.max(0, current - 1);
    if (key == LogicalKeyboardKey.home) next = 0;
    if (key == LogicalKeyboardKey.end) next = last;
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

  String _describe(ChartSlot slot) {
    final french = widget.french;
    return [
      fullChartLabel(slot.label, french),
      if (slot.main != null)
        '${formatChartValue(slot.main!.value, widget.unit, french)}, ${entryCount(slot.main!.count, french)}',
      if (slot.delta != null) formatDelta(slot.delta!, french),
      if (slot.comparison != null)
        '${french ? 'Période comparée' : 'Comparison period'} ${fullChartLabel(slot.comparison!.label, french)}: ${formatChartValue(slot.comparison!.value, widget.unit, french)}',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final french = widget.french;
    final theme = Theme.of(context);
    final colors = ChartColors.of(theme.brightness);
    if (widget.rows.length == 1) return _keyFigure(theme, widget.rows.first);
    if (widget.rows.length < 2) return const SizedBox.shrink();
    final characterScale = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3).scale(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [_legend(theme, colors), _viewSwitch(theme)],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final geometry = _ChartGeometry(
                size: Size(constraints.maxWidth, widget.height),
                slots: _slots,
                allSlots: _allSlots,
                view: widget.view,
                showMain: _showMain,
                showComparison: _showComparison,
                french: french,
                characterScale: characterScale,
              );
              return _interactivePlot(context, geometry, colors);
            },
          ),
        ),
        if (_allSlots.length > maxChartPoints)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              french
                  ? 'Courbe simplifiée : ${_slots.length} points affichés sur ${_allSlots.length}. La liste ci-dessous contient tout.'
                  : 'Simplified chart: ${_slots.length} of ${_allSlots.length} points shown. The list below contains every point.',
              style: TextStyle(color: colors.muted, fontSize: 13),
            ),
          ),
      ],
    );
  }

  Widget _keyFigure(ThemeData theme, Map<String, dynamic> row) {
    final french = widget.french;
    final point = ChartPoint.fromRow(row);
    final muted = ChartColors.of(theme.brightness).muted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(french ? 'Chiffre clé' : 'Key figure', style: TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          '${row['value']}${widget.unit == null ? '' : ' ${widget.unit}'}',
          style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text('${point.label} · ${entryCount(point.count, french)}', style: TextStyle(color: muted, fontSize: 13)),
      ],
    );
  }

  Widget _legend(ThemeData theme, ChartColors colors) {
    final french = widget.french;
    final mainName = '${french ? 'Résultat par groupe' : 'Result by group'}${widget.unit == null ? '' : ' · ${widget.unit}'}';
    if (!_compared) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LineKey(color: colors.main, dashed: false),
          const SizedBox(width: 8),
          Flexible(child: Text(mainName, style: TextStyle(color: colors.muted, fontSize: 13))),
        ],
      );
    }
    Widget item(_Series series, String label, Color color) {
      final isolated = _isolated == series;
      final hidden = series == _Series.main ? !_showMain : !_showComparison;
      return Semantics(
        button: true,
        toggled: isolated,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() {
            _isolated = isolated ? null : series;
            _active.value = null;
          }),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LineKey(color: color, dashed: series == _Series.comparison),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
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
      );
    }

    return Wrap(
      children: [
        item(_Series.main, mainName, colors.main),
        item(_Series.comparison, french ? 'Période comparée' : 'Comparison period', colors.comparison),
      ],
    );
  }

  Widget _viewSwitch(ThemeData theme) {
    if (widget.views.length < 2) return const SizedBox.shrink();
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
        if (widget.views.contains(ChartView.line))
          button(ChartView.line, french ? 'Courbe' : 'Line', Icons.show_chart_rounded),
        if (widget.views.contains(ChartView.bar))
          button(ChartView.bar, french ? 'Barres' : 'Bars', Icons.bar_chart_rounded),
      ],
    );
  }

  Widget _interactivePlot(BuildContext context, _ChartGeometry geometry, ChartColors colors) {
    final french = widget.french;
    void pick(Offset position) => _select(geometry.indexAt(position.dx));
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TapRegion(
      onTapOutside: (_) => _active.value = null,
      child: ValueListenableBuilder<int?>(
        valueListenable: _active,
        builder: (context, active, plot) {
          final last = _slots.length - 1;
          final current = math.min(last, active ?? _rove);
          final next = math.min(last, current + 1);
          final previous = math.max(0, current - 1);
          return Semantics(
            container: true,
            label: '${french ? 'Graphique' : 'Chart'}: ${_allSlots.length} ${french ? 'groupes' : 'groups'}',
            value: _describe(_slots[current]),
            increasedValue: _describe(_slots[next]),
            decreasedValue: _describe(_slots[previous]),
            onIncrease: () => _select(next),
            onDecrease: () => _select(previous),
            child: plot,
          );
        },
        child: Focus(
          focusNode: _focus,
          onKeyEvent: _onKey,
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
            // A horizontal drag selects points; a vertical one still scrolls the page.
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
                        key: const ValueKey('analysis-chart-series'),
                        painter: _SeriesPainter(geometry, colors),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _SelectionPainter(geometry, colors, _active),
                      ),
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
                          if (active == null || active >= _slots.length) return const SizedBox.shrink();
                          return TweenAnimationBuilder<Offset>(
                            tween: Tween<Offset>(end: geometry.anchorFor(active)),
                            duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 90),
                            curve: Curves.easeOutCubic,
                            builder: (context, anchor, child) => CustomSingleChildLayout(
                              delegate: _TooltipLayout(anchor),
                              child: child,
                            ),
                            child: _ChartTooltip(
                              slot: _slots[active],
                              unit: widget.unit,
                              french: french,
                              colors: colors,
                              showMain: _showMain,
                              showComparison: _showComparison,
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

class _LineKey extends StatelessWidget {
  const _LineKey({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 22,
    height: 2,
    child: CustomPaint(painter: _LineKeyPainter(color, dashed)),
  );
}

class _LineKeyPainter extends CustomPainter {
  const _LineKeyPainter(this.color, this.dashed);

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    final y = size.height / 2;
    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, y), Offset(math.min(size.width, x + 5), y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineKeyPainter old) => old.color != color || old.dashed != dashed;
}

class _ChartGeometry {
  _ChartGeometry({
    required this.size,
    required this.slots,
    required List<ChartSlot> allSlots,
    required this.view,
    required this.showMain,
    required this.showComparison,
    required this.french,
    required this.characterScale,
  }) : scale = niceScale([
         for (final slot in allSlots) ...[
           if (showMain && slot.main != null) slot.main!.value,
           if (showComparison && slot.comparison != null) slot.comparison!.value,
         ],
       ]) {
    final longest = scale.ticks.fold<int>(0, (size, tick) => math.max(size, compactChartNumber(tick, french).length));
    left = math.min(72, math.max(36, longest * 8 * characterScale + 12));
    plotWidth = math.max(40, size.width - left - right);
    band = plotWidth / slots.length;
    positions = [
      for (var index = 0; index < slots.length; index++)
        view == ChartView.line
            ? left + index * plotWidth / math.max(1, slots.length - 1)
            : left + band * (index + 0.5),
    ];
    ticks = chooseAxisTicks(
      [for (final slot in slots) slot.label],
      positions,
      french,
      characterWidth: 7 * characterScale,
    );
    axis = size.height - 34;
    final drawn = (showMain ? 1 : 0) + (showComparison ? 1 : 0);
    drawnBars = math.max(1, drawn);
    barWidth = math.max(1, math.min(24, (band - math.min(4, band * 0.3) - (drawn > 1 ? 2 : 0)) / drawnBars));
  }

  static const top = 14.0;
  static const right = 14.0;

  final Size size;
  final List<ChartSlot> slots;
  final ChartView view;
  final bool showMain;
  final bool showComparison;
  final bool french;
  final double characterScale;
  final ChartScale scale;
  late final double left;
  late final double plotWidth;
  late final double band;
  late final double axis;
  late final double barWidth;
  late final int drawnBars;
  late final List<double> positions;
  late final List<AxisTick> ticks;

  bool get isLine => view == ChartView.line;
  double y(double value) => axis - (value - scale.low) / (scale.high - scale.low) * (axis - top);
  double get baseline => y(0);
  bool get showDots => plotWidth / slots.length >= 14;

  int indexAt(double dx) {
    var best = 0;
    for (var index = 1; index < positions.length; index++) {
      if ((positions[index] - dx).abs() < (positions[best] - dx).abs()) best = index;
    }
    return best;
  }

  Offset anchorFor(int index) {
    final slot = slots[index];
    final values = [
      if (showMain && slot.main != null) slot.main!.value,
      if (showComparison && slot.comparison != null) slot.comparison!.value,
    ];
    return Offset(positions[index], y(values.isEmpty ? scale.low : values.reduce(math.max)));
  }

  List<List<Offset>> runs(ChartPoint? Function(ChartSlot) pick) {
    final result = <List<Offset>>[[]];
    for (var index = 0; index < slots.length; index++) {
      final point = pick(slots[index]);
      if (point != null) {
        result.last.add(Offset(positions[index], y(point.value)));
      } else if (result.last.isNotEmpty) {
        result.add([]);
      }
    }
    return result.where((run) => run.isNotEmpty).toList();
  }
}

Path _dashed(Path source, double dash, double gap) {
  final result = Path();
  for (final metric in source.computeMetrics()) {
    for (double distance = 0; distance < metric.length; distance += dash + gap) {
      result.addPath(metric.extractPath(distance, math.min(metric.length, distance + dash)), Offset.zero);
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

class _SeriesPainter extends CustomPainter {
  const _SeriesPainter(this.geometry, this.colors);

  final _ChartGeometry geometry;
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

  void _lines(Canvas canvas, _ChartGeometry g) {
    if (g.showMain) {
      for (final run in g.runs((slot) => slot.main)) {
        if (run.length > 1) {
          final area = _polyline(run)
            ..lineTo(run.last.dx, g.baseline)
            ..lineTo(run.first.dx, g.baseline)
            ..close();
          canvas.drawPath(
            area,
            Paint()
              ..shader = ui.Gradient.linear(Offset(0, _ChartGeometry.top), Offset(0, g.baseline), [
                colors.main.withValues(alpha: 0.2),
                colors.main.withValues(alpha: 0.02),
              ]),
          );
        }
      }
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (g.showComparison) {
      stroke.color = colors.comparison.withValues(alpha: 0.85);
      for (final run in g.runs((slot) => slot.comparison)) {
        canvas.drawPath(_dashed(_polyline(run), 6, 5), stroke);
      }
    }
    if (g.showMain) {
      stroke.color = colors.main;
      for (final run in g.runs((slot) => slot.main)) {
        canvas.drawPath(_polyline(run), stroke);
        if (g.showDots) {
          for (final point in run) {
            canvas.drawCircle(point, 4, Paint()..color = colors.surface);
            canvas.drawCircle(point, 3, Paint()..color = colors.main);
          }
        }
      }
    }
  }

  void _bars(Canvas canvas, _ChartGeometry g) {
    const corner = Radius.circular(4);
    void bar(double x, ChartPoint? point, Color color, bool comparison) {
      if (point == null || point.value == 0) return;
      final y = g.y(point.value);
      final rect = Rect.fromLTRB(x, math.min(y, g.baseline), x + g.barWidth, math.max(y, g.baseline));
      final shape = point.value > 0
          ? RRect.fromRectAndCorners(rect, topLeft: corner, topRight: corner)
          : RRect.fromRectAndCorners(rect, bottomLeft: corner, bottomRight: corner);
      canvas.drawRRect(shape, Paint()..color = comparison ? color.withValues(alpha: 0.45) : color);
      if (comparison) {
        canvas.drawPath(
          _dashed(Path()..addRRect(shape), 3, 2),
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke,
        );
      }
    }

    for (var index = 0; index < g.slots.length; index++) {
      final slot = g.slots[index];
      var cursor = g.positions[index] - (g.barWidth * g.drawnBars + (g.drawnBars > 1 ? 2 : 0)) / 2;
      if (g.showMain) {
        bar(cursor, slot.main, colors.main, false);
        cursor += g.barWidth + 2;
      }
      if (g.showComparison) bar(cursor, slot.comparison, colors.comparison, true);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final g = geometry;
    final grid = Paint()
      ..color = colors.line
      ..strokeWidth = 1;
    for (final tick in g.scale.ticks) {
      canvas.drawLine(Offset(g.left, g.y(tick)), Offset(size.width - _ChartGeometry.right, g.y(tick)), grid);
      _text(canvas, compactChartNumber(tick, g.french), Offset(g.left - 6, g.y(tick)), align: TextAlign.right);
    }
    if (g.isLine) {
      _lines(canvas, g);
    } else {
      _bars(canvas, g);
    }
    canvas.drawLine(
      Offset(g.left, g.baseline),
      Offset(size.width - _ChartGeometry.right, g.baseline),
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
      !identical(old.geometry.slots, geometry.slots) ||
      old.geometry.view != geometry.view ||
      old.geometry.showMain != geometry.showMain ||
      old.geometry.showComparison != geometry.showComparison ||
      old.geometry.french != geometry.french ||
      old.colors != colors;
}

class _SelectionPainter extends CustomPainter {
  _SelectionPainter(this.geometry, this.colors, this.active) : super(repaint: active);

  final _ChartGeometry geometry;
  final ChartColors colors;
  final ValueListenable<int?> active;

  @override
  void paint(Canvas canvas, Size size) {
    final index = active.value;
    final g = geometry;
    if (index == null || index >= g.slots.length) return;
    final slot = g.slots[index];
    final x = g.positions[index];
    if (!g.isLine) {
      canvas.drawRect(
        Rect.fromLTRB(x - g.band / 2, _ChartGeometry.top, x + g.band / 2, g.axis),
        Paint()..color = colors.muted.withValues(alpha: 0.14),
      );
      return;
    }
    canvas.drawLine(
      Offset(x, _ChartGeometry.top),
      Offset(x, g.axis),
      Paint()
        ..color = colors.muted
        ..strokeWidth = 1,
    );
    if (g.showComparison && slot.comparison != null) {
      final point = Offset(x, g.y(slot.comparison!.value));
      canvas.drawCircle(point, 5, Paint()..color = colors.surface);
      canvas.drawCircle(
        point,
        5,
        Paint()
          ..color = colors.comparison
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    if (g.showMain && slot.main != null) {
      final point = Offset(x, g.y(slot.main!.value));
      canvas.drawCircle(point, 7, Paint()..color = colors.surface);
      canvas.drawCircle(point, 5, Paint()..color = colors.main);
    }
  }

  @override
  bool shouldRepaint(covariant _SelectionPainter old) => !identical(old.geometry, geometry) || old.colors != colors;
}

class _TooltipLayout extends SingleChildLayoutDelegate {
  const _TooltipLayout(this.anchor);

  final Offset anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(maxWidth: math.min(250.0, constraints.maxWidth));

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final left = (anchor.dx - childSize.width / 2).clamp(0.0, math.max(0.0, size.width - childSize.width)).toDouble();
    final above = anchor.dy - childSize.height - 12;
    return Offset(left, above >= 0 ? above : anchor.dy + 14);
  }

  @override
  bool shouldRelayout(covariant _TooltipLayout old) => old.anchor != anchor;
}

class _ChartTooltip extends StatelessWidget {
  const _ChartTooltip({
    required this.slot,
    required this.unit,
    required this.french,
    required this.colors,
    required this.showMain,
    required this.showComparison,
  });

  final ChartSlot slot;
  final String? unit;
  final bool french;
  final ChartColors colors;
  final bool showMain;
  final bool showComparison;

  @override
  Widget build(BuildContext context) {
    final main = showMain ? slot.main : null;
    final comparison = showComparison ? slot.comparison : null;
    final meta = TextStyle(color: colors.muted, fontSize: 13);
    final delta = slot.delta;
    return Material(
      key: const ValueKey('analysis-chart-tooltip'),
      color: colors.surface,
      elevation: 6,
      shadowColor: Colors.black38,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (main != null) ...[
              Text(formatChartValue(main.value, unit, french), style: TextStyle(color: colors.ink, fontSize: 15, fontWeight: FontWeight.w600)),
              Text(fullChartLabel(main.label, french), style: meta),
              Wrap(
                spacing: 8,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(entryCount(main.count, french), style: meta),
                  if (delta != null) _DeltaBadge(delta: delta, french: french, colors: colors),
                ],
              ),
            ],
            if (comparison != null) ...[
              if (main != null) Divider(height: 10, color: colors.line),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LineKey(color: colors.comparison, dashed: true),
                  const SizedBox(width: 6),
                  Flexible(child: Text(formatChartValue(comparison.value, unit, french), style: TextStyle(color: colors.ink, fontSize: 13, fontWeight: FontWeight.w600))),
                ],
              ),
              Text('${fullChartLabel(comparison.label, french)} · ${entryCount(comparison.count, french)}', style: meta),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({required this.delta, required this.french, required this.colors});

  final double delta;
  final bool french;
  final ChartColors colors;

  @override
  Widget build(BuildContext context) {
    final up = delta > 0;
    final down = delta < 0;
    final foreground = up ? colors.success : down ? colors.danger : colors.ink;
    final background = up ? colors.successSoft : down ? colors.dangerSoft : colors.line;
    return DecoratedBox(
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(6)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Text(
          '${up ? '▲ ' : down ? '▼ ' : ''}${formatDelta(delta, french)}',
          style: TextStyle(color: foreground, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
