import 'package:brainy/analysis_chart.dart';
import 'package:brainy/chart_math.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _row(String group, String value, [int count = 1]) => {
  'group': group,
  'label': group,
  'value': value,
  'count': count,
  'sources': <Map<String, dynamic>>[],
  'sourcesHasMore': false,
};

ChartPoint _point(String group, double value) =>
    ChartPoint(group: group, label: group, value: value, count: 1);

final _months = [
  _row('2026-01', '12450', 42),
  _row('2026-02', '13800', 43),
  _row('2026-03', '11200', 44),
];
final _previous = [
  _row('2025-01', '9000', 30),
  _row('2025-02', '12000', 31),
  _row('2025-03', '10500', 32),
];

Future<void> _mount(
  WidgetTester tester, {
  double width = 320,
  bool french = true,
  ChartView view = ChartView.line,
  List<Map<String, dynamic>>? rows,
  List<Map<String, dynamic>> comparison = const [],
  ValueChanged<ChartView>? onView,
}) async {
  tester.view.physicalSize = Size(width, 820);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: StatefulBuilder(
              builder: (context, setState) => AnalysisChart(
                rows: rows ?? _months,
                comparisonRows: comparison,
                unit: 'EUR',
                french: french,
                view: view,
                views: const [ChartView.line, ChartView.bar],
                onViewChange: (next) {
                  onView?.call(next);
                  setState(() => view = next);
                },
                height: 210,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder get _series => find.byKey(const ValueKey('analysis-chart-series'));
Finder get _tooltip => find.byKey(const ValueKey('analysis-chart-tooltip'));

/// Global position of the middle point of three.
Offset _middle(WidgetTester tester) {
  final box = tester.renderObject<RenderBox>(_series);
  return box.localToGlobal(Offset(box.size.width / 2 + 10, 90));
}

void main() {
  group('chart math matches the web client', () {
    test('LTTB keeps a peak and both ends', () {
      final values = [for (var i = 0; i < 1000; i++) i == 512 ? 5000.0 : (i % 2).toDouble()];
      final kept = lttbIndices(values, 100);
      expect(kept, hasLength(100));
      expect(kept, contains(512));
      expect([kept.first, kept.last], [0, 999]);
      expect(kept, orderedEquals([...kept]..sort()));
      expect(lttbIndices([1, 2, 3], 10), [0, 1, 2]);
    });

    test('variation uses the magnitude and refuses a zero base', () {
      expect(deltaPercent(150, 100), 50);
      expect(deltaPercent(50, -100), 150);
      expect(deltaPercent(5, 0), isNull);
      expect(deltaPercent(5, null), isNull);
    });

    test('scale keeps zero and contains the values', () {
      final scale = niceScale([12450, 18250]);
      expect(scale.low, 0);
      expect(scale.high, greaterThanOrEqualTo(18250));
      expect(niceScale([0.01, 0.04]).high, 0.04);
      expect(niceScale([-5, 20]).low, lessThanOrEqualTo(-5));
      expect(niceScale([0, 0]).high, greaterThan(0));
    });

    test('periods align by position and categories by key', () {
      final periods = alignSeries(
        [_point('2026-01', 1), _point('2026-02', 2)],
        [_point('2025-01', 9), _point('2025-02', 8)],
      );
      expect(periods.map((slot) => slot.comparison!.group), ['2025-01', '2025-02']);
      expect(periods[1].delta, 100);
      final categories = alignSeries(
        [_point('A', 1), _point('B', 2)],
        [_point('B', 7), _point('C', 3)],
      );
      expect(categories.map((slot) => slot.key), ['A', 'B', 'C']);
      expect(categories[0].comparison, isNull);
      expect(categories[1].comparison!.value, 7);
      expect(categories[2].main, isNull);
    });

    test('values, variations and counts are written for each language', () {
      expect(formatChartValue(13800, 'EUR', true), '13 800,00 EUR');
      expect(formatChartValue(13800, 'EUR', false), '13,800.00 EUR');
      expect(formatChartValue(3.5, 'kg', true), '3,5 kg');
      expect(formatChartValue(-0.125, null, false), '-0.125');
      expect(formatDelta(10.84, true), '+10,8 %');
      expect(formatDelta(-18.8, false), '-18.8 %');
      expect(entryCount(1, true), '1 entrée');
      expect(entryCount(43, true), '43 entrées');
      expect(entryCount(1, false), '1 entry');
      expect(compactChartNumber(12500, true), '12,5 k');
      expect(compactChartNumber(12500, false), '12.5K');
      expect(compactChartNumber(0, true), '0');
      expect(fullChartLabel('2026-02', true), 'février 2026');
      expect(fullChartLabel('2026-02-05', false), 'February 5, 2026');
      expect(fullChartLabel('Water', true), 'Water');
    });

    test('a thinned series still gets separate calendar graduations', () {
      final days = [
        for (final i in [0, 3, 40, 41, 75, 120, 200, 300, 400, 499])
          DateTime.utc(2025, 1, 1 + i).toIso8601String().substring(0, 10),
      ];
      final ticks = chooseAxisTicks(days, [for (var i = 0; i < days.length; i++) 20.0 + i * 100], false);
      expect(ticks.length, greaterThanOrEqualTo(3));
      expect(ticks.map((tick) => tick.label).toSet(), hasLength(ticks.length));
    });
  });

  group('AnalysisChart', () {
    testWidgets('a tap shows value, full date, entries and variation at 320 px', (tester) async {
      await _mount(tester, comparison: _previous);
      expect(_tooltip, findsNothing);
      await tester.tapAt(_middle(tester));
      await tester.pump(const Duration(milliseconds: 150));
      expect(_tooltip, findsOneWidget);
      expect(find.text('13 800,00 EUR'), findsOneWidget);
      expect(find.text('février 2026'), findsOneWidget);
      expect(find.text('43 entrées'), findsOneWidget);
      expect(find.textContaining('▲ +10,8 %'), findsOneWidget);
      expect(find.text('12 000,00 EUR'), findsOneWidget);
      expect(find.textContaining('février 2025'), findsOneWidget);
      final chart = tester.getRect(find.byType(AnalysisChart));
      final tip = tester.getRect(_tooltip);
      expect(tip.left, greaterThanOrEqualTo(chart.left - 1));
      expect(tip.right, lessThanOrEqualTo(chart.right + 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a horizontal drag follows the finger and a fall is marked', (tester) async {
      await _mount(tester);
      final box = tester.renderObject<RenderBox>(_series);
      final gesture = await tester.startGesture(box.localToGlobal(Offset(box.size.width / 2, 90)));
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await gesture.moveTo(box.localToGlobal(Offset(box.size.width - 4, 90)));
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('mars 2026'), findsOneWidget);
      expect(find.textContaining('▼ -18,8 %'), findsOneWidget);
      await gesture.up();
      await tester.pump();
    });

    testWidgets('moving the selection does not repaint the series layer', (tester) async {
      await _mount(tester, comparison: _previous);
      final series = tester.renderObject<RenderCustomPaint>(_series);
      await tester.tapAt(_middle(tester));
      await tester.pump(const Duration(milliseconds: 150));
      expect(series.debugNeedsPaint, isFalse);
      final before = series.painter;
      await tester.tapAt(_middle(tester) + const Offset(80, 0));
      await tester.pump(const Duration(milliseconds: 150));
      expect(identical(tester.renderObject<RenderCustomPaint>(_series).painter, before), isTrue);
    });

    testWidgets('mouse hover shows the tooltip and leaving hides it', (tester) async {
      await _mount(tester, width: 1000, french: false);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(1, 700));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(_middle(tester));
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('13,800.00 EUR'), findsOneWidget);
      expect(find.textContaining('▲ +10.8 %'), findsOneWidget);
      await mouse.moveTo(const Offset(1, 700));
      await tester.pump();
      expect(_tooltip, findsNothing);
    });

    testWidgets('keyboard moves between points and Escape hides the tooltip', (tester) async {
      await _mount(tester, width: 1000, french: false);
      await tester.tapAt(_middle(tester));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('January 2026'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('February 2026'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('March 2026'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(_tooltip, findsNothing);
    });

    testWidgets('the legend isolates a series and restores both', (tester) async {
      await _mount(tester, comparison: _previous, french: false);
      await tester.tap(find.text('Comparison period'));
      await tester.pump();
      await tester.tapAt(_middle(tester));
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('12,000.00 EUR'), findsOneWidget);
      expect(find.text('13,800.00 EUR'), findsNothing, reason: 'the main series is hidden');
      await tester.tap(find.text('Comparison period'));
      await tester.pump();
      await tester.tapAt(_middle(tester));
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('13,800.00 EUR'), findsOneWidget);
    });

    testWidgets('the view buttons report the chosen chart', (tester) async {
      ChartView? chosen;
      await _mount(tester, french: false, onView: (next) => chosen = next);
      await tester.tap(find.byTooltip('Bars'));
      await tester.pump();
      expect(chosen, ChartView.bar);
      await tester.tapAt(_middle(tester));
      await tester.pump(const Duration(milliseconds: 150));
      expect(_tooltip, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('more than 100 rows are thinned and announced', (tester) async {
      final dense = [
        for (var i = 0; i < 500; i++)
          _row(DateTime.utc(2025, 1, 1 + i).toIso8601String().substring(0, 10), '${100 + i % 40}'),
      ];
      await _mount(tester, rows: dense, french: false);
      expect(find.textContaining('100 of 500 points'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('one row stays a key figure', (tester) async {
      await _mount(tester, rows: [_row('Water', '3.5', 2)], french: false);
      expect(find.text('Key figure'), findsOneWidget);
      expect(find.text('3.5 EUR'), findsOneWidget);
      expect(find.text('Water · 2 entries'), findsOneWidget);
      expect(_series, findsNothing);
    });

    testWidgets('doubled text does not overflow at 320 px in dark theme', (tester) async {
      tester.view.physicalSize = const Size(320, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: MediaQuery(
            data: const MediaQueryData(size: Size(320, 820), textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: AnalysisChart(
                  rows: _months,
                  comparisonRows: _previous,
                  unit: 'EUR',
                  french: true,
                  view: ChartView.line,
                  views: const [ChartView.line, ChartView.bar],
                  onViewChange: (_) {},
                  height: 210,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tapAt(_middle(tester));
      await tester.pump(const Duration(milliseconds: 150));
      expect(_tooltip, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
