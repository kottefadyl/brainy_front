import 'package:brainy/analysis_chart.dart' show ChartView;
import 'package:brainy/analysis_multi_series_chart.dart';
import 'package:brainy/chart_math.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _cell(String period, String key, String label, num value, {bool periodFirst = true}) => {
  'group': periodFirst ? '$period × $key' : '$key × $period',
  'label': periodFirst ? '$period × $label' : '$label × $period',
  'rowKey': periodFirst ? period : key,
  'columnKey': periodFirst ? key : period,
  'value': '$value',
  'count': 3,
  'sources': <Map<String, dynamic>>[],
  'sourcesHasMore': false,
};

/// Twelve months × six products; February has no tea and one value has no date.
final _rows = [
  for (var month = 1; month <= 12; month++)
    for (final (key, label, base) in [
      ('pain', 'Pain de campagne au levain naturel', 4200),
      ('cafe', 'Café', 3100),
      ('the', 'Thé', 900),
      ('jus', 'Jus d’orange', 1500),
      ('gateau', 'Gâteaux', 700),
      ('soupe', 'Soupe', 300),
    ])
      if (!(key == 'the' && month == 2)) _cell('2026-${'$month'.padLeft(2, '0')}', key, label, base + month * 10),
  _cell('Missing date', 'pain', 'Pain de campagne au levain naturel', 50),
];

Future<void> _mount(WidgetTester tester, {double width = 320, bool french = true, double textScale = 1, Brightness brightness = Brightness.light}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  var view = ChartView.line;
  final multi = splitCrossTab(_rows, 'MONTH', 'CATEGORY')!;
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 900), textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: StatefulBuilder(
                builder: (context, setState) => AnalysisMultiSeriesChart(
                  multi: multi,
                  unit: 'EUR',
                  french: french,
                  view: view,
                  onViewChange: (next) => setState(() => view = next),
                  height: 230,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder get _plot => find.byKey(const ValueKey('multi-series-chart-series'));
Finder get _tooltip => find.byKey(const ValueKey('multi-series-chart-tooltip'));

void main() {
  group('splitCrossTab', () {
    test('keeps the four largest totals, in calendar order, and counts undated values', () {
      final multi = splitCrossTab(_rows, 'MONTH', 'CATEGORY')!;
      expect(multi.periods.first, '2026-01');
      expect(multi.periods, hasLength(12));
      expect(multi.series.map((series) => series.key), ['pain', 'cafe', 'jus', 'the']);
      expect(multi.hiddenSeries, 2);
      expect(multi.skippedRows, 1);
      expect(multi.series.first.label, 'Pain de campagne au levain naturel');
      expect(multi.series[3].points[1], isNull, reason: 'a missing cell is a gap, not a zero');
    });

    test('ranks by magnitude and reads labels when the period is the second axis', () {
      final rows = [
        for (final period in ['2026-01', '2026-02']) ...[
          _cell(period, 'a', 'Alpha × bêta', 1, periodFirst: false),
          _cell(period, 'b', 'B', -30, periodFirst: false),
        ],
      ];
      final multi = splitCrossTab(rows, 'CATEGORY', 'MONTH')!;
      expect(multi.series.map((series) => series.key), ['b', 'a']);
      expect(multi.series[1].label, 'Alpha × bêta');
      expect(multi.series[1].points.map((point) => point!.value), [1, 1]);
    });

    test('no series chart without a period axis or with a single period', () {
      expect(splitCrossTab(_rows, 'CATEGORY', 'OBJECT'), isNull);
      expect(splitCrossTab([_cell('2026-01', 'a', 'A', 1), _cell('2026-01', 'b', 'B', 2)], 'MONTH', 'CATEGORY'), isNull);
    });
  });

  testWidgets('draws four series with a note on the categories left to the list', (tester) async {
    await _mount(tester);
    expect(find.text('Pain de campagne au levain naturel'), findsOneWidget);
    expect(find.text('Soupe'), findsNothing);
    expect(find.textContaining('4 catégories sur 6 tracées'), findsOneWidget);
    expect(find.textContaining('1 valeur sans date'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the tooltip lists every series and says when one has no data', (tester) async {
    await _mount(tester, width: 1000);
    final box = tester.renderObject<RenderBox>(_plot);
    // February is the second of twelve evenly spread periods.
    final left = box.localToGlobal(Offset.zero).dx;
    final x = left + 72 + (box.size.width - 72 - 14) / 11;
    await tester.tapAt(Offset(x, box.localToGlobal(Offset.zero).dy + 80));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_tooltip, findsOneWidget);
    expect(find.descendant(of: _tooltip, matching: find.text('février 2026')), findsOneWidget);
    expect(find.descendant(of: _tooltip, matching: find.text('aucune donnée')), findsOneWidget);
    expect(find.descendant(of: _tooltip, matching: find.text('Café')), findsOneWidget);
  });

  testWidgets('hiding series never hides the last one', (tester) async {
    await _mount(tester, french: false);
    for (var index = 0; index < 4; index++) {
      await tester.tap(find.byKey(ValueKey('multi-series-legend-$index')));
      await tester.pump();
    }
    final struck = [
      for (var index = 0; index < 4; index++)
        tester
            .widget<Text>(find.descendant(of: find.byKey(ValueKey('multi-series-legend-$index')), matching: find.byType(Text)))
            .style
            ?.decoration,
    ];
    expect(struck.where((decoration) => decoration == TextDecoration.lineThrough), hasLength(3));
  });

  testWidgets('keyboard moves between periods and Escape closes the tooltip', (tester) async {
    await _mount(tester, width: 1000, french: false);
    await tester.tapAt(tester.getCenter(_plot));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.descendant(of: _tooltip, matching: find.text('December 2026')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.descendant(of: _tooltip, matching: find.text('January 2026')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(_tooltip, findsNothing);
  });

  testWidgets('bars, dark theme and doubled text fit at 320 px', (tester) async {
    await _mount(tester, textScale: 2, brightness: Brightness.dark);
    await tester.tap(find.byTooltip('Barres'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(_plot, findsOneWidget);
  });
}
